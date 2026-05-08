import Foundation

// MARK: - Personalized Home Insights (Build 1 — Home Feature 1)
// Generates a Cyrano-driven insight for the home screen using the user's
// real activity. Caches once-per-day so we don't hit the API on every
// home view appearance. Three rotating insight types — connection / attachment /
// weekly-focus — chosen deterministically from the day of the year.

struct HomeInsight: Codable, Equatable {
    var dateKey: String          // "yyyy-MM-dd" — invalidates when day changes
    var typeRaw: String          // InsightType.rawValue
    var body: String             // Cyrano text
    var actionableTip: String    // mapped from weakest RI dimension

    var type: HomeInsightType { HomeInsightType(rawValue: typeRaw) ?? .connection }
}

enum HomeInsightType: String, Codable {
    case connection
    case attachment
    case weeklyFocus

    var eyebrow: String {
        switch self {
        case .connection:  return "CONNECTION TIP"
        case .attachment:  return "ATTACHMENT LENS"
        case .weeklyFocus: return "WEEKLY FOCUS"
        }
    }
}

@MainActor
@Observable
final class HomeInsightsService {
    static let shared = HomeInsightsService()
    private init() { load() }

    var current: HomeInsight?
    var isGenerating = false

    private static let cacheKey = "home.insight.cached.v1"
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    // MARK: - Public

    /// Returns the cached insight if it matches today; otherwise generates a
    /// fresh one in the background and updates `current`.
    func loadIfStale() async {
        let todayKey = Self.dateFormatter.string(from: Date())
        if let cur = current, cur.dateKey == todayKey { return }
        await regenerate(force: false)
    }

    /// Force-regenerates the insight (e.g., user pulled a refresh affordance).
    func regenerate(force: Bool) async {
        guard !isGenerating || force else { return }
        isGenerating = true
        defer { isGenerating = false }

        let todayKey = Self.dateFormatter.string(from: Date())
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let type: HomeInsightType
        switch dayOfYear % 3 {
        case 0:  type = .weeklyFocus
        case 1:  type = .connection
        default: type = .attachment
        }

        let weakest = weakestDimension()
        let actionable = actionableTip(for: weakest)

        let cyranoBody = await generateCyranoInsight(type: type)

        let insight = HomeInsight(
            dateKey: todayKey,
            typeRaw: type.rawValue,
            body: cyranoBody,
            actionableTip: actionable
        )
        current = insight
        save()
    }

    // MARK: - Generation

    private func generateCyranoInsight(type: HomeInsightType) async -> String {
        // Bail to a static fallback if AI is off, so the home card never
        // shows a blank frame.
        guard AISettings.shared.isEnabled else { return staticFallback(for: type) }

        let context = userContextSnapshot()
        let role = """
        YOUR ROLE NOW: Daily home insight from Cyrano.

        \(context)

        INSIGHT TYPE: \(type.rawValue)
        - connection:  one specific observation about how to connect better today, grounded in the user's archive activity or relationship status.
        - attachment:  a short reframe through the user's attachment style.
        - weeklyFocus: one quality to embody this week, given the user's lowest RI dimension.

        Write 2-3 sentences MAX. Specific, warm, actionable. No headers, no bullets, no preamble. Address the user by first name once if natural.
        """

        do {
            let raw = try await Claude.shared.send(
                system: role,
                user: "Write the insight now.",
                max: 220
            )
            let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? staticFallback(for: type) : cleaned
        } catch {
            return staticFallback(for: type)
        }
    }

    private func userContextSnapshot() -> String {
        let user = AuthService.shared.currentUser
        let name = (user?.name).flatMap { $0.isEmpty ? nil : $0 } ?? "the user"
        let attachment = user?.attachmentStyle.rawValue ?? "Secure"
        let status = user?.relationshipStatus.displayLabel ?? "I'm single"

        let streak = StreakManager.shared.currentStreak
        let archive = ArchiveStore.shared.active.count
        let lastAddedDays = ArchiveStore.shared.active
            .max(by: { $0.createdAt < $1.createdAt })
            .map { Int(Date().timeIntervalSince($0.createdAt) / 86400) }

        let score = RIScoreStore.shared.score
        let weakestName = weakestDimensionName()

        let daysOnApp: Int = {
            guard let createdAt = user?.createdAt else { return 0 }
            return Int(Date().timeIntervalSince(createdAt) / 86400)
        }()

        let rel = RelationshipStore.shared.relationship
        let relLine = rel.map { "Partner: \($0.partnerName), together since \($0.startDate.formatted(.dateTime.month().year()))." } ?? ""

        return """
        USER CONTEXT:
        - Name: \(name)
        - Attachment style: \(attachment)
        - Relationship status: \(status)
        - Days using Rowan: \(daysOnApp)
        - Streak: \(streak) days
        - Archive: \(archive) connections\(lastAddedDays.map { ", last added \($0) days ago" } ?? "")
        - RI Score total: \(score.total) — lowest dimension: \(weakestName)
        \(relLine)
        """
    }

    // MARK: - Weakest RI dimension

    enum RIDimension: String { case presence, attunement, repairScore, vulnerability, curiosity, consistency
        var displayName: String {
            switch self {
            case .presence:      return "Presence"
            case .attunement:    return "Attunement"
            case .repairScore:   return "Repair"
            case .vulnerability: return "Vulnerability"
            case .curiosity:     return "Curiosity"
            case .consistency:   return "Consistency"
            }
        }
    }

    private func weakestDimension() -> RIDimension {
        let s = RIScoreStore.shared.score
        let values: [(RIDimension, Int)] = [
            (.presence, s.presence),
            (.attunement, s.attunement),
            (.repairScore, s.repairScore),
            (.vulnerability, s.vulnerability),
            (.curiosity, s.curiosity),
            (.consistency, s.consistency)
        ]
        return values.min(by: { $0.1 < $1.1 })?.0 ?? .consistency
    }

    private func weakestDimensionName() -> String { weakestDimension().displayName }

    private func actionableTip(for d: RIDimension) -> String {
        switch d {
        case .presence:
            return "Try the Voice Trainer's Presence Check today — three minutes."
        case .attunement:
            return "Run a Face to Face Sim with a Distracted personality — practice earning attention."
        case .repairScore:
            return "Open the Communication Lab's Repair Attempts lesson tonight."
        case .vulnerability:
            return "Use a Connection Card today — start with the Warm deck."
        case .curiosity:
            return "In your next conversation, ask three questions before sharing anything."
        case .consistency:
            return "Pick one Daily Ritual and do it tonight."
        }
    }

    private func staticFallback(for type: HomeInsightType) -> String {
        switch type {
        case .connection:
            return "Specificity beats generality every time. Reference one thing they actually said today and watch the conversation deepen."
        case .attachment:
            return "Your patterns aren't your prison. Notice them, name them, and you've already started rewriting them."
        case .weeklyFocus:
            return "Pick one quality to embody this week. Pace, presence, curiosity. Just one — and let it shape how you show up."
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let stored = try? JSONDecoder().decode(HomeInsight.self, from: data)
        else { return }
        current = stored
    }

    private func save() {
        guard let cur = current,
              let data = try? JSONEncoder().encode(cur) else { return }
        UserDefaults.standard.set(data, forKey: Self.cacheKey)
    }
}
