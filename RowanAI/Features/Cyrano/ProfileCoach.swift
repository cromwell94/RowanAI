import SwiftUI

// MARK: - Dating App enum + prompt library

enum DatingApp: String, CaseIterable, Identifiable, Codable {
    case hinge          = "Hinge"
    case bumble         = "Bumble"
    case tinder         = "Tinder"
    case coffee         = "Coffee Meets Bagel"
    case feeld          = "Feeld"
    case league         = "The League"
    case thursday       = "Thursday"
    case other          = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .hinge:    return "h.circle.fill"
        case .bumble:   return "b.circle.fill"
        case .tinder:   return "flame.fill"
        case .coffee:   return "cup.and.saucer.fill"
        case .feeld:    return "infinity.circle.fill"
        case .league:   return "crown.fill"
        case .thursday: return "calendar"
        case .other:    return "questionmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .hinge:    return Color(hex: "8E2DE2")
        case .bumble:   return Color(hex: "F0B500")
        case .tinder:   return Color(hex: "FE3C72")
        case .coffee:   return Color(hex: "8B5E3C")
        case .feeld:    return Color(hex: "5B8DEF")
        case .league:   return Color(hex: "0D0D0D")
        case .thursday: return Color(hex: "00BFB3")
        case .other:    return .rwAccent
        }
    }

    var promptLibrary: [String] {
        switch self {
        case .hinge:
            return [
                "The most spontaneous thing I've done",
                "I'm looking for",
                "My love language is",
                "Typical Sunday",
                "I go crazy for",
                "The key to my heart",
                "I know the best spot in town for",
                "Two truths and a lie",
                "Never have I ever",
                "My simple pleasures",
                "This year I really want to",
                "Unusual skills",
                "We'll get along if",
                "I'm convinced that",
                "Dating me is like",
                "All I ask is that",
                "The one thing you should know about me",
                "I'm weirdly attracted to",
                "Believe it or not, I",
                "A life goal of mine"
            ]
        case .bumble:
            return [
                "My ideal Sunday",
                "The way to win me over",
                "I'm looking for someone who",
                "My most controversial opinion",
                "I want someone who",
                "Fact about me that surprises people",
                "This year I want to",
                "My friends describe me as"
            ]
        case .tinder:
            return [
                "My anthem",
                "I go crazy for",
                "I'm looking for",
                "My simple pleasures",
                "We're the same kind of weird if"
            ]
        case .coffee, .feeld, .league, .thursday, .other:
            return []
        }
    }
}

// MARK: - Photo analysis local model

struct PhotoAnalysis: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var imageData: Data            // JPEG-compressed
    var score: Int = 0
    var positives: [String] = []
    var improvements: [String] = []
    var recommendation: Recommendation = .secondary
    var reason: String = ""
    var analyzed: Bool = false
    var analyzing: Bool = false
    var failed: Bool = false

    enum Recommendation: String, Codable {
        case lead     = "Lead Photo"
        case secondary = "Secondary Photo"
        case cut      = "Cut This One"

        var sortOrder: Int {
            switch self {
            case .lead:     return 0
            case .secondary: return 1
            case .cut:      return 2
            }
        }

        var icon: String {
            switch self {
            case .lead:     return "star.fill"
            case .secondary: return "checkmark.circle.fill"
            case .cut:      return "xmark.circle.fill"
            }
        }
    }

    var image: UIImage? { UIImage(data: imageData) }

    /// Score color: green 8-10, amber 5-7, red 1-4.
    var scoreColor: Color {
        switch score {
        case 8...10: return .rwSuccess
        case 5...7:  return .rwWarning
        default:     return .rwDanger
        }
    }

    static func from(_ image: UIImage) -> PhotoAnalysis? {
        // Compress to JPEG so the in-memory store doesn't balloon.
        guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
        return PhotoAnalysis(imageData: data)
    }
}

// MARK: - Profile Coach Store

@MainActor
@Observable
final class ProfileCoachStore {
    static let shared = ProfileCoachStore()

    var selectedApp: DatingApp = .hinge

    var uploadedPhotos: [PhotoAnalysis] = []

    /// Map of prompt-text → user's saved current answer
    var savedPromptAnswers: [String: String] = [:]
    /// Map of prompt-text → Cyrano-generated options
    var generatedPrompts: [String: Claude.ProfilePromptOptions] = [:]

    var currentBio: String = ""
    var bioThreeThings: String = ""
    var bioLookingFor: BioLookingFor = .open
    var bioDifferent: String = ""
    var generatedBios: Claude.ProfileBioOptions? = nil

    var profileDescription: String = ""
    var draftOpener: String = ""
    var generatedOpeners: Claude.ProfileOpenerOptions? = nil

    enum BioLookingFor: String, CaseIterable, Identifiable, Codable {
        case casual    = "Casual"
        case serious   = "Something serious"
        case open      = "Open to anything"
        case unsure    = "Not sure yet"

        var id: String { rawValue }
    }

    private init() { load() }

    // MARK: - Persistence (lightweight; photos NOT persisted on disk)

    private static let appKey      = "profileCoach.app.v1"
    private static let answersKey  = "profileCoach.answers.v1"
    private static let bioKey      = "profileCoach.bio.v1"
    private static let openerKey   = "profileCoach.opener.v1"

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(selectedApp.rawValue, forKey: Self.appKey)
        if let data = try? JSONEncoder().encode(savedPromptAnswers) {
            defaults.set(data, forKey: Self.answersKey)
        }
        if let data = try? JSONEncoder().encode(BioState(
            current: currentBio,
            threeThings: bioThreeThings,
            lookingFor: bioLookingFor,
            different: bioDifferent
        )) {
            defaults.set(data, forKey: Self.bioKey)
        }
        if let data = try? JSONEncoder().encode(OpenerState(
            description: profileDescription,
            draft: draftOpener
        )) {
            defaults.set(data, forKey: Self.openerKey)
        }
    }

    private func load() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: Self.appKey),
           let app = DatingApp(rawValue: raw) {
            selectedApp = app
        }
        if let data = defaults.data(forKey: Self.answersKey),
           let map = try? JSONDecoder().decode([String: String].self, from: data) {
            savedPromptAnswers = map
        }
        if let data = defaults.data(forKey: Self.bioKey),
           let state = try? JSONDecoder().decode(BioState.self, from: data) {
            currentBio = state.current
            bioThreeThings = state.threeThings
            bioLookingFor = state.lookingFor
            bioDifferent = state.different
        }
        if let data = defaults.data(forKey: Self.openerKey),
           let state = try? JSONDecoder().decode(OpenerState.self, from: data) {
            profileDescription = state.description
            draftOpener = state.draft
        }
    }

    private struct BioState: Codable {
        var current: String
        var threeThings: String
        var lookingFor: BioLookingFor
        var different: String
    }

    private struct OpenerState: Codable {
        var description: String
        var draft: String
    }

    /// Photos are reordered and grouped by recommendation. Lead first, then
    /// Secondary, then Cut at the bottom (greyed out by the view).
    var orderedPhotos: [PhotoAnalysis] {
        // Stable sort by recommendation order, then by score desc.
        uploadedPhotos.sorted { a, b in
            if a.recommendation.sortOrder != b.recommendation.sortOrder {
                return a.recommendation.sortOrder < b.recommendation.sortOrder
            }
            return a.score > b.score
        }
    }
}

// MARK: - Entry Card
// Lives on the Cyrano landing surface. Tap → open ProfileCoachView as a sheet.

struct ProfileCoachEntryCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: RR.md)
                        .fill(LinearGradient.accent)
                        .frame(width: 52, height: 52)
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Optimize Your Dating Profile")
                        .font(RWF.head(15))
                        .foregroundColor(.rwTextPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Photos, prompts, bio, and opening messages.")
                        .font(RWF.cap(12))
                        .foregroundColor(.rwTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Text("Let's Go").font(RWF.cap(12))
                    Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(LinearGradient.accent)
                .clipShape(Capsule())
                .shadow(color: Color.rwAccent.opacity(0.30), radius: 6, x: 0, y: 2)
            }
            .padding(SP.md)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(
                RoundedRectangle(cornerRadius: RR.xl)
                    .strokeBorder(LinearGradient.accent, lineWidth: 1.5)
            )
            .shadow(color: Color.rwAccent.opacity(0.15), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Profile Coach View
// Sheet root. Top tab bar (Photos · Prompts · Bio · Opening) with back button.

struct ProfileCoachView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .photos
    @State private var store = ProfileCoachStore.shared

    enum Tab: String, CaseIterable, Identifiable {
        case photos  = "Photos"
        case prompts = "Prompts"
        case bio     = "Bio"
        case opening = "Opening"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .photos:  return "photo.stack.fill"
            case .prompts: return "text.quote"
            case .bio:     return "person.text.rectangle.fill"
            case .opening: return "envelope.fill"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                RWSegmentedPicker(
                    options: Tab.allCases.map { (value: $0, label: $0.rawValue, icon: $0.icon) },
                    selected: $tab
                )
                .padding(.horizontal, SP.lg).padding(.top, 8).padding(.bottom, 4)

                content
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.18), value: tab)
            }
            .rwBG()
            .navigationTitle("Profile Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        store.save()
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            Text("Cyrano").font(RWF.cap(13))
                        }
                        .foregroundColor(.rwAccent)
                    }
                }
            }
            .onDisappear { store.save() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .photos:  ProfilePhotoTab()
        case .prompts: ProfilePromptTab()
        case .bio:     ProfileBioTab()
        case .opening: ProfileOpeningTab()
        }
    }
}
