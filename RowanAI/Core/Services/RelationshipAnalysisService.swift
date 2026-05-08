import Foundation
import SwiftUI

// MARK: - Analysis Store
//
// Persists the latest RelationshipAnalysis per contact plus a bounded history
// of past analyses (last 30) so the user can see how Cyrano's read evolved.
// File-backed with .completeFileProtection like the rest of the Archive data.

@Observable
final class AnalysisStore {
    static let shared = AnalysisStore()

    /// Current analysis per contact, keyed by Person.id.
    var current: [String: RelationshipAnalysis] = [:]

    /// History of past analyses per contact, newest first. Capped at 30
    /// entries per contact to keep the file bounded.
    var history: [String: [RelationshipAnalysis]] = [:]

    private static let historyCap = 30

    private struct Snapshot: Codable {
        var current: [String: RelationshipAnalysis]
        var history: [String: [RelationshipAnalysis]]
    }

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("relationship_analysis_v1.json")
    }

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return }
        current = snap.current
        history = snap.history
    }

    func save() {
        let snap = Snapshot(current: current, history: history)
        guard let data = try? JSONEncoder().encode(snap) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func analysis(for contactID: String) -> RelationshipAnalysis? {
        current[contactID]
    }

    func history(for contactID: String) -> [RelationshipAnalysis] {
        history[contactID] ?? []
    }

    func record(_ analysis: RelationshipAnalysis) {
        let id = analysis.contactID
        // Push the previous "current" into history before replacing.
        if let prior = current[id] {
            var bucket = history[id] ?? []
            bucket.insert(prior, at: 0)
            if bucket.count > Self.historyCap { bucket = Array(bucket.prefix(Self.historyCap)) }
            history[id] = bucket
        }
        current[id] = analysis
        save()
    }

    func clearAll(for contactID: String) {
        current.removeValue(forKey: contactID)
        history.removeValue(forKey: contactID)
        save()
    }
}

// MARK: - Relationship Analysis Service
//
// Builds a comprehensive prompt from everything Rowan knows about a contact
// (cross-platform messages, dates, intel notes, days since first contact),
// asks Cyrano for an honest read as JSON, and persists the result.
//
// Auto-generation is rate-limited to once per hour per contact to control API
// costs and avoid noise. Manual refresh always bypasses the rate limit.

final class RelationshipAnalysisService {
    static let shared = RelationshipAnalysisService()

    private static let autoCooldown: TimeInterval = 60 * 60 // 1 hour

    enum AnalysisError: Error {
        case aiOff
        case insufficientData
        case parse
        case underlying(Error)
    }

    /// Whether enough data exists for a meaningful analysis. The Overview card
    /// uses this to decide between the empty-state copy and a real analysis.
    static func hasEnoughData(for contact: Person) -> Bool {
        let messages = ChatThreadStore.shared.messageCount(for: contact.id)
        let dates = contact.dateHistory.count
        return messages >= 3 || dates >= 1
    }

    /// True when the most recent analysis is younger than the auto cooldown
    /// — auto-triggers should be skipped.
    func isOnCooldown(contactID: String) -> Bool {
        guard let last = AnalysisStore.shared.analysis(for: contactID) else { return false }
        return Date().timeIntervalSince(last.lastUpdatedAt) < Self.autoCooldown
    }

    // MARK: - Triggers

    /// Auto-trigger called by ChatThreadStore mutations, date logging, etc.
    /// Honors the cooldown; safe to spam from many call sites.
    func generateIfNeeded(for contact: Person) {
        guard !isOnCooldown(contactID: contact.id) else { return }
        guard Self.hasEnoughData(for: contact) else { return }
        Task { _ = try? await generate(for: contact, force: false) }
    }

    /// Manual refresh — always runs regardless of cooldown. Used by the
    /// Refresh button on the Cyrano's Read card.
    @discardableResult
    func refresh(for contact: Person) async throws -> RelationshipAnalysis {
        try await generate(for: contact, force: true)
    }

    // MARK: - Core Generation

    @discardableResult
    func generate(for contact: Person, force: Bool) async throws -> RelationshipAnalysis {
        guard AISettings.shared.isEnabled else { throw AnalysisError.aiOff }
        guard force || Self.hasEnoughData(for: contact) else {
            throw AnalysisError.insufficientData
        }

        let messages = ChatThreadStore.shared.allMessages(for: contact.id)
        let dates = contact.dateHistory
        let platformCount = ChatThreadStore.shared.platformCount(for: contact.id)
        let intelCount = contact.thingsToAsk.count + contact.thingsToAvoid.count + contact.keyFacts.count

        let prompt = Self.buildPrompt(
            contact: contact,
            messages: messages,
            dates: dates,
            platformCount: platformCount,
            intelCount: intelCount
        )

        let raw: String
        do {
            raw = try await Claude.shared.send(
                system: prompt.system,
                user: prompt.user,
                max: 1200
            )
        } catch {
            throw AnalysisError.underlying(error)
        }

        let cleaned = Claude.shared.clean(raw)
        guard let parsed = Self.parseJSON(cleaned, contactID: contact.id) else {
            throw AnalysisError.parse
        }

        var analysis = parsed
        analysis.dataPoints = messages.count + dates.count + intelCount
        analysis.sourceMessageCount = messages.count
        analysis.sourceDateCount = dates.count
        analysis.sourceIntelCount = intelCount
        analysis.lastUpdatedAt = Date()

        AnalysisStore.shared.record(analysis)
        return analysis
    }

    // MARK: - Prompt Building

    private struct Prompt { let system: String; let user: String }

    private static func buildPrompt(
        contact: Person,
        messages: [ThreadMessage],
        dates: [DateEntry],
        platformCount: Int,
        intelCount: Int
    ) -> Prompt {

        // Conversation history — chronological, with platform tags so Cyrano
        // can spot platform-shifts as part of the dynamic.
        let df = DateFormatter()
        df.dateFormat = "MMM d, h:mm a"
        let history: String
        if messages.isEmpty {
            history = "No messages logged yet."
        } else {
            history = messages.map { m in
                "[\(df.string(from: m.timestamp)) · \(m.platform.rawValue)] \(m.sender.rawValue): \(m.text)"
            }.joined(separator: "\n")
        }

        // Dates — outcomes if logged.
        let dateBlock: String
        if dates.isEmpty {
            dateBlock = "No dates logged yet."
        } else {
            dateBlock = dates.map { d in
                let when = DateFormatter.localizedString(from: d.date, dateStyle: .medium, timeStyle: .none)
                let rating = d.rating > 0 ? " · \(d.rating)/5" : ""
                let where_ = d.location.isEmpty ? "" : " at \(d.location)"
                let notes = d.notes.isEmpty ? "" : " — \(d.notes)"
                return "• \(when)\(where_)\(rating)\(notes)"
            }.joined(separator: "\n")
        }

        let intel = [
            contact.thingsToAsk.isEmpty ? nil : "Things to ask: " + contact.thingsToAsk.joined(separator: "; "),
            contact.thingsToAvoid.isEmpty ? nil : "Things to avoid: " + contact.thingsToAvoid.joined(separator: "; "),
            contact.keyFacts.isEmpty ? nil : "Key facts: " + contact.keyFacts.joined(separator: "; "),
            contact.greenFlags.isEmpty ? nil : "Green flags: " + contact.greenFlags.joined(separator: "; "),
            contact.redFlags.isEmpty ? nil : "Red flags: " + contact.redFlags.joined(separator: "; ")
        ].compactMap { $0 }.joined(separator: "\n")

        let extraNotes = [contact.notes, contact.privateNotes]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")

        let firstAdded = DateFormatter.localizedString(from: contact.createdAt,
                                                      dateStyle: .medium,
                                                      timeStyle: .none)
        let daysSinceAdded = Calendar.current.dateComponents([.day],
                                                             from: contact.createdAt,
                                                             to: Date()).day ?? 0

        let system = """
        You are Cyrano, a relational intelligence coach. Your job here is the Living Relationship Analysis: an honest, specific, evidence-based read on a single connection, refreshed any time new data lands.

        STRICT RULES:
        - Never be falsely positive. If it's stalled, say stalled.
        - Be specific. Cite something that actually happened. No generic platitudes.
        - If signals are mixed, say so. Don't pick a side that isn't there.
        - If there isn't enough data for a confident read, choose momentum "Too early to tell".
        - Output ONLY a single JSON object. No preamble, no markdown fences, no trailing commentary.

        OUTPUT SHAPE (every key required, in this exact order):
        {
          "momentum": "Building" | "Steady" | "Fading" | "Stalled" | "Too early to tell",
          "connectionStage": "Just Met" | "Early Conversation" | "Building Rapport" | "Clear Interest" | "Date Territory" | "Dating" | "Getting Exclusive" | "It's Complicated",
          "overallRead": "<2-3 honest sentences on the actual dynamic>",
          "greenFlags": ["<specific signal>", "..."],
          "yellowFlags": ["<specific thing to watch>", "..."],
          "patterns": ["<recurring behavior>", "..."],
          "currentGuidance": "<one specific actionable instruction for right now>",
          "nextMoveAdvice": "<exactly what to say or do next — specific, not generic>"
        }
        """

        let user = """
        PERSON: \(contact.name)
        FIRST ADDED: \(firstAdded) (\(daysSinceAdded) days ago)
        TOTAL MESSAGES LOGGED: \(messages.count) across \(platformCount) platform\(platformCount == 1 ? "" : "s")
        TOTAL DATES LOGGED: \(dates.count)
        INTEL NOTES LOGGED: \(intelCount)

        CONVERSATION HISTORY:
        \(history)

        DATES:
        \(dateBlock)

        INTEL NOTES:
        \(intel.isEmpty ? "None." : intel)

        ADDITIONAL NOTES:
        \(extraNotes.isEmpty ? "None." : extraNotes)

        Return ONLY the JSON object described above.
        """

        return Prompt(system: system, user: user)
    }

    // MARK: - JSON Parsing

    private static func parseJSON(_ raw: String, contactID: String) -> RelationshipAnalysis? {
        // Strip any stray fences or leading commentary, then locate the first
        // balanced JSON object — Cyrano usually obeys the "ONLY JSON" rule but
        // this guards against the occasional preamble.
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate: String = {
            if let start = trimmed.firstIndex(of: "{"),
               let end = trimmed.lastIndex(of: "}"),
               start < end {
                return String(trimmed[start...end])
            }
            return trimmed
        }()

        guard let data = candidate.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let momentum = (obj["momentum"] as? String).flatMap { RelationshipAnalysis.MomentumLevel(rawValue: $0) }
            ?? .unclear
        let stage = (obj["connectionStage"] as? String).flatMap { RelationshipAnalysis.ConnectionStage(rawValue: $0) }
            ?? .justMet

        return RelationshipAnalysis(
            contactID: contactID,
            momentum: momentum,
            connectionStage: stage,
            overallRead: (obj["overallRead"] as? String) ?? "",
            greenFlags: (obj["greenFlags"] as? [String]) ?? [],
            yellowFlags: (obj["yellowFlags"] as? [String]) ?? [],
            patterns: (obj["patterns"] as? [String]) ?? [],
            currentGuidance: (obj["currentGuidance"] as? String) ?? "",
            nextMoveAdvice: (obj["nextMoveAdvice"] as? String) ?? ""
        )
    }
}
