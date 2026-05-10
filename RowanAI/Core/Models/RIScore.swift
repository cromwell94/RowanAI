import Foundation
import SwiftUI

// MARK: - Relational Intelligence Score
//
// Six dimensions × 0-200 each = total 0-1000 (master tier).
// Every activity that affects a dimension records an RIScoreEvent so the
// dashboard's activity feed and 30-day chart reflect real movement.

struct RIScore: Codable, Equatable {
    var presence: Int       // Voice Confidence Trainer + The Sim engagement
    var attunement: Int     // Reading personality types in sim, lessons, post-date reflection
    var repairScore: Int    // Relationship-mode-only; recovery after conflict
    var vulnerability: Int  // Connection cards, evening debrief depth
    var curiosity: Int      // Question ratio in The Sim sessions
    var consistency: Int    // Streak, ritual completion, weekly cadence

    var total: Int {
        presence + attunement + repairScore + vulnerability + curiosity + consistency
    }

    var level: RILevel { RILevel.forTotal(total) }

    /// Distance to the next level. Returns nil at Master.
    var pointsToNextLevel: Int? {
        switch level {
        case .developing: return 200 - total
        case .emerging:   return 400 - total
        case .growing:    return 600 - total
        case .connected:  return 800 - total
        case .fluent:     return 1000 - total
        case .master:     return nil
        }
    }

    var nextLevel: RILevel? {
        switch level {
        case .developing: return .emerging
        case .emerging:   return .growing
        case .growing:    return .connected
        case .connected:  return .fluent
        case .fluent:     return .master
        case .master:     return nil
        }
    }

    /// Spec-defined starting scores for new users.
    static let starter = RIScore(
        presence: 80,
        attunement: 60,
        repairScore: 80,
        vulnerability: 80,
        curiosity: 60,
        consistency: 40
    )

    /// Subscript for the by-dimension activity feed and the dimension grid.
    func value(for dimension: RIDimension) -> Int {
        switch dimension {
        case .presence:      return presence
        case .attunement:    return attunement
        case .repair:        return repairScore
        case .vulnerability: return vulnerability
        case .curiosity:     return curiosity
        case .consistency:   return consistency
        }
    }
}

// MARK: - Dimension

enum RIDimension: String, Codable, CaseIterable, Identifiable {
    case presence      = "Presence"
    case attunement    = "Attunement"
    case repair        = "Repair"
    case vulnerability = "Vulnerability"
    case curiosity     = "Curiosity"
    case consistency   = "Consistency"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .presence:      return "eye.fill"
        case .attunement:    return "waveform.path.ecg"
        case .repair:        return "bandage.fill"
        case .vulnerability: return "heart.fill"
        case .curiosity:     return "magnifyingglass"
        case .consistency:   return "calendar"
        }
    }

    var color: Color {
        switch self {
        case .presence:      return Color(hex: "5B8DEF")
        case .attunement:    return Color(hex: "00BFB3")
        case .repair:        return Color(hex: "C0A020")
        case .vulnerability: return Color(hex: "E8356D")
        case .curiosity:     return Color(hex: "8E44AD")
        case .consistency:   return Color(hex: "F59E0B")
        }
    }

    var feeders: [String] {
        switch self {
        case .presence:
            return ["The Sim sessions", "Voice Confidence Trainer", "First Impression Lab"]
        case .attunement:
            return ["Reading personalities in Sim", "Sim win conditions", "Post-date reflections", "Body Language reading"]
        case .repair:
            return ["Health checks", "Hard Conversation Simulator", "Daily ritual streaks"]
        case .vulnerability:
            return ["Connection cards", "Evening debriefs", "Desire Map", "Real-talk apology practice"]
        case .curiosity:
            return ["Genuine follow-up questions in Sim", "Sessions where you talked < 50%", "Open-ended question patterns"]
        case .consistency:
            return ["Daily streak", "Weekly rituals", "Multi-week cadence"]
        }
    }

    /// Specific suggestion shown in the "How to improve" section when this is
    /// the user's lowest dimension.
    var improvementTip: String {
        switch self {
        case .presence:
            return "Run a The Sim session. Holding presence under social pressure is the fastest way to build this."
        case .attunement:
            return "Try Assessment Mode in The Sim with any personality and focus on reading the body language signals."
        case .repair:
            return "Complete a couples Health Check or run the Hard Conversation Simulator — both feed Repair fast."
        case .vulnerability:
            return "Answer tonight's evening debrief with more than a sentence. Depth feeds this dimension directly."
        case .curiosity:
            return "Pick the Overthinker in The Sim and focus on asking follow-up questions tied to what they actually said."
        case .consistency:
            return "Show up tomorrow. Even a single check-in maintains your streak — the points compound."
        }
    }
}

// MARK: - Level

enum RILevel: String, Codable, CaseIterable {
    case developing = "Developing"
    case emerging   = "Emerging"
    case growing    = "Growing"
    case connected  = "Connected"
    case fluent     = "Fluent"
    case master     = "Master"

    static func forTotal(_ total: Int) -> RILevel {
        switch total {
        case ..<200:   return .developing
        case ..<400:   return .emerging
        case ..<600:   return .growing
        case ..<800:   return .connected
        case ..<1000:  return .fluent
        default:       return .master
        }
    }

    var threshold: Int {
        switch self {
        case .developing: return 0
        case .emerging:   return 200
        case .growing:    return 400
        case .connected:  return 600
        case .fluent:     return 800
        case .master:     return 1000
        }
    }

    var color: Color {
        switch self {
        case .developing: return Color(hex: "9BA8BF")
        case .emerging:   return Color(hex: "5B8DEF")
        case .growing:    return Color(hex: "F59E0B")
        case .connected:  return Color(hex: "00BFB3")
        case .fluent:     return Color(hex: "9B59B6")
        case .master:     return Color(hex: "E8356D")
        }
    }

    var blurb: String {
        switch self {
        case .developing:
            return "You're building the muscle of relational awareness. Every session, every check-in, every honest conversation grows it."
        case .emerging:
            return "Patterns are starting to click. You can name what you're seeing in conversations now."
        case .growing:
            return "You're more attuned than most people. Your reads are getting accurate."
        case .connected:
            return "You're connecting with depth. People feel seen around you."
        case .fluent:
            return "Relational intelligence is second nature for you now. You move through hard conversations with ease."
        case .master:
            return "Master tier. The work is the practice — keep going, keep refining."
        }
    }
}

// MARK: - Score Event (activity feed)

struct RIScoreEvent: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var dimension: RIDimension
    var points: Int           // Signed delta
    var reason: String        // Short, human-readable label for the feed
    var timestamp: Date = Date()
}

// MARK: - Score Snapshot (chart series)
//
// One entry per day on which the score changed. Lets the 30-day chart show
// peaks after active practice without needing per-event resolution.

struct RIScoreSnapshot: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var date: Date
    var total: Int
}

// MARK: - RI Score Store

@Observable
class RIScoreStore {
    static let shared = RIScoreStore()

    var score: RIScore = .starter
    var events: [RIScoreEvent] = []         // Newest first
    var history: [RIScoreSnapshot] = []     // Oldest first

    /// Set when a level threshold was just crossed; the dashboard reads this
    /// once and clears it so the milestone celebration only fires once.
    var pendingLevelUp: RILevel? = nil

    private struct Snapshot: Codable {
        var score: RIScore
        var events: [RIScoreEvent]
        var history: [RIScoreSnapshot]
    }

    private static let eventCap = 200       // Plenty for the activity feed
    private static let historyCap = 365     // ~1 year of daily totals

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ri_score_v2.json")
    }

    /// Older v1 path — used to migrate forward into the v2 store the first
    /// time we run after the upgrade.
    private var legacyFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ri_score_v1.json")
    }

    init() { load() }

    // MARK: - Persistence

    func load() {
        if let data = try? Data(contentsOf: fileURL),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            score = snap.score
            events = snap.events
            history = snap.history
            return
        }
        // Forward-migrate from v1 (just the score, no events/history).
        if let data = try? Data(contentsOf: legacyFileURL),
           let v1 = try? JSONDecoder().decode(RIScore.self, from: data) {
            score = v1
            // Seed history with today's total so the chart isn't blank.
            history = [RIScoreSnapshot(date: Calendar.current.startOfDay(for: Date()),
                                       total: v1.total)]
            save()
        }
    }

    func save() {
        let snap = Snapshot(score: score, events: events, history: history)
        guard let data = try? JSONEncoder().encode(snap) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    // MARK: - Recording (canonical entry point)
    //
    // All bump methods route through `record` so events + history are kept in
    // sync. Use this from feature code instead of mutating `score` directly.

    func record(dimension: RIDimension, points: Int, reason: String) {
        guard points != 0 else { return }
        let priorTotal = score.total
        let priorLevel = score.level
        applyDelta(points, to: dimension)

        // Activity feed
        let event = RIScoreEvent(dimension: dimension, points: points, reason: reason)
        events.insert(event, at: 0)
        if events.count > Self.eventCap {
            events = Array(events.prefix(Self.eventCap))
        }

        // History — overwrite today's entry if present, otherwise append.
        let today = Calendar.current.startOfDay(for: Date())
        if let i = history.lastIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            history[i].total = score.total
        } else {
            history.append(RIScoreSnapshot(date: today, total: score.total))
        }
        if history.count > Self.historyCap {
            history = Array(history.suffix(Self.historyCap))
        }

        // Level-up detection — fire only on a positive crossing.
        let newLevel = score.level
        if newLevel != priorLevel && newLevel.threshold > priorLevel.threshold && score.total > priorTotal {
            pendingLevelUp = newLevel
        }

        save()
    }

    private func applyDelta(_ delta: Int, to dimension: RIDimension) {
        switch dimension {
        case .presence:      score.presence      = clamp(score.presence + delta)
        case .attunement:    score.attunement    = clamp(score.attunement + delta)
        case .repair:        score.repairScore   = clamp(score.repairScore + delta)
        case .vulnerability: score.vulnerability = clamp(score.vulnerability + delta)
        case .curiosity:     score.curiosity     = clamp(score.curiosity + delta)
        case .consistency:   score.consistency   = clamp(score.consistency + delta)
        }
    }

    private func clamp(_ value: Int) -> Int { min(200, max(0, value)) }

    /// Read the level-up flag once. The view shows the celebration overlay
    /// when this returns non-nil and clears it.
    func consumePendingLevelUp() -> RILevel? {
        let level = pendingLevelUp
        pendingLevelUp = nil
        return level
    }

    // MARK: - Trend
    //
    // Returns the dimension's delta vs the same dimension's value 7 days ago,
    // approximated from history snapshots. Used by the trend arrow on each
    // dimension card.

    enum Trend { case up, steady, down }

    func trend(for dimension: RIDimension) -> Trend {
        // We snapshot total only; per-dimension trend would need per-dimension
        // history. For now, compute total trend and apply same indicator
        // across the grid. Good enough for the surface-level cue.
        guard let lastWeek = history.first(where: {
            Calendar.current.dateComponents([.day], from: $0.date, to: Date()).day ?? 0 >= 7
        }) else { return .steady }
        let delta = score.total - lastWeek.total
        if delta >= 8 { return .up }
        if delta <= -4 { return .down }
        return .steady
    }

    /// 30-day daily-total series for the chart. Pads missing days with the
    /// previous known total so the line is continuous.
    func last30Days() -> [RIScoreSnapshot] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -29, to: today) else { return history }

        var byDay: [Date: Int] = [:]
        for snap in history { byDay[cal.startOfDay(for: snap.date)] = snap.total }

        var result: [RIScoreSnapshot] = []
        var lastKnown = history.first(where: { $0.date <= start })?.total ?? score.total
        for offset in 0..<30 {
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { continue }
            if let total = byDay[day] {
                lastKnown = total
            }
            result.append(RIScoreSnapshot(date: day, total: lastKnown))
        }
        return result
    }

    // MARK: - Backwards-compatible bumpers
    // Existing call sites keep working. Each one routes through `record` so
    // the activity feed picks up the change automatically.

    func bumpPresence(by delta: Int, reason: String = "Presence activity") {
        record(dimension: .presence, points: delta, reason: reason)
    }

    func bumpAttunement(by delta: Int, reason: String = "Attunement activity") {
        record(dimension: .attunement, points: delta, reason: reason)
    }

    func bumpRepair(by delta: Int, reason: String = "Repair activity") {
        record(dimension: .repair, points: delta, reason: reason)
    }

    func bumpVulnerability(by delta: Int, reason: String = "Vulnerability activity") {
        record(dimension: .vulnerability, points: delta, reason: reason)
    }

    func bumpCuriosity(by delta: Int, reason: String = "Curiosity activity") {
        record(dimension: .curiosity, points: delta, reason: reason)
    }

    func bumpConsistency(by delta: Int, reason: String = "Consistency activity") {
        record(dimension: .consistency, points: delta, reason: reason)
    }
}
