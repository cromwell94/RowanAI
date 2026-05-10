import Foundation

// MARK: - Tutorial Manager
// Central registry of which tutorials the user has seen + a global on/off
// toggle. Persists across launches via UserDefaults. SwiftUI views observe
// this directly through the @Observable macro — bind from any screen with
// `@State private var tutorials = TutorialManager.shared`.

@MainActor
@Observable
final class TutorialManager {
    static let shared = TutorialManager()

    /// Master switch. When false, `shouldShow` always returns false regardless
    /// of seen state. Defaults on for new users.
    var tutorialsEnabled: Bool {
        didSet { UserDefaults.standard.set(tutorialsEnabled, forKey: Self.enabledKey) }
    }

    /// IDs the user has already completed (or skipped).
    private(set) var seenTutorials: Set<TutorialID> = []

    private static let enabledKey = "tutorials.enabled"
    private static let seenKey    = "tutorials.seen"

    private init() {
        // Default on for new users; preserved otherwise.
        if UserDefaults.standard.object(forKey: Self.enabledKey) == nil {
            self.tutorialsEnabled = true
            UserDefaults.standard.set(true, forKey: Self.enabledKey)
        } else {
            self.tutorialsEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        }
        loadSeen()
    }

    // MARK: - API

    func markSeen(_ id: TutorialID) {
        guard !seenTutorials.contains(id) else { return }
        seenTutorials.insert(id)
        persistSeen()
    }

    /// True iff tutorials are enabled AND this id hasn't been marked seen.
    func shouldShow(_ id: TutorialID) -> Bool {
        tutorialsEnabled && !seenTutorials.contains(id)
    }

    /// Force-show — used by the "Replay tutorial" affordance on each screen.
    func replay(_ id: TutorialID) {
        seenTutorials.remove(id)
        persistSeen()
    }

    /// Wipes all "seen" records — used by the Settings reset and during testing.
    func resetAll() {
        seenTutorials.removeAll()
        persistSeen()
    }

    // MARK: - Persistence

    private func loadSeen() {
        guard let data = UserDefaults.standard.data(forKey: Self.seenKey),
              let arr  = try? JSONDecoder().decode([TutorialID].self, from: data)
        else { return }
        seenTutorials = Set(arr)
    }

    private func persistSeen() {
        let arr = Array(seenTutorials)
        if let data = try? JSONEncoder().encode(arr) {
            UserDefaults.standard.set(data, forKey: Self.seenKey)
        }
    }
}

// MARK: - Tutorial IDs

enum TutorialID: String, Codable, CaseIterable {
    case home
    case cyrano
    case sim
    case firstImpressionLab
    case archive
    case datePlanner
    case debrief
    case relationshipHome
    case communicationLab
    case rituals
    case intimacy
    case growth
    case riScore
    case voiceTrainer
    case breakupRecovery
    case screenshotAnalysis
    case contactPhotos
    case meetInTheMiddle
}
