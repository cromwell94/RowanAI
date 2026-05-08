import SwiftUI

// MARK: - Cyrano Exercise Suggestion (Build 1)
// When Cyrano notices the user is stuck on a recognizable pattern (anxious
// spiral, avoidance, ending avoidance, etc.), it appends a "---" suggestion
// block to its reply output. The client parses it, renders a tappable card
// below the replies, and deep-links to the relevant exercise.

struct CyranoExerciseSuggestion: Equatable, Identifiable {
    let pattern: PatternKind
    let title: String
    let blurb: String

    var id: String { pattern.rawValue }
    var target: Target { pattern.defaultTarget }

    enum PatternKind: String, CaseIterable, Codable {
        case anxiousSpiral             = "anxious_spiral"
        case avoidance                 = "avoidance"
        case conflictAvoidance         = "conflict_avoidance"
        case overPursuit               = "over_pursuit"
        case vulnerabilityBlock        = "vulnerability_block"
        case communicationBreakdown    = "communication_breakdown"
        case situationshipConfusion    = "situationship_confusion"
        case endingAvoidance           = "ending_avoidance"
        case firstImpressionNerves     = "first_impression_nerves"
        case rejectionProcessing       = "rejection_processing"

        var prettyName: String {
            switch self {
            case .anxiousSpiral:           return "anxious spiral"
            case .avoidance:               return "avoidance"
            case .conflictAvoidance:       return "conflict avoidance"
            case .overPursuit:             return "over-pursuit"
            case .vulnerabilityBlock:      return "vulnerability block"
            case .communicationBreakdown:  return "communication breakdown"
            case .situationshipConfusion:  return "situationship confusion"
            case .endingAvoidance:         return "ending avoidance"
            case .firstImpressionNerves:   return "first-impression nerves"
            case .rejectionProcessing:     return "rejection processing"
            }
        }

        var defaultTarget: Target {
            switch self {
            case .anxiousSpiral:
                return .faceToFaceSim(personality: .overthinker, mode: .single)
            case .avoidance:
                return .faceToFaceSim(personality: .guarded, mode: .single)
            case .conflictAvoidance:
                return .relationshipCommLab
            case .overPursuit:
                return .faceToFaceSim(personality: .distracted, mode: .single)
            case .vulnerabilityBlock:
                return .voiceTrainer
            case .communicationBreakdown:
                return .relationshipCommLab
            case .situationshipConfusion:
                return .faceToFaceSim(personality: .confrontational, mode: .complicated, environment: .firstDate)
            case .endingAvoidance:
                return .faceToFaceSim(personality: .overthinker, mode: .complicated, environment: .collegeCampus)
            case .firstImpressionNerves:
                return .firstImpressionLab
            case .rejectionProcessing:
                return .breakupRecovery
            }
        }

        var defaultExercise: (title: String, blurb: String) {
            switch self {
            case .anxiousSpiral:
                return ("Face to Face Sim · Overthinker",
                        "Practice staying present with someone who mirrors your anxiety back at you.")
            case .avoidance:
                return ("Face to Face Sim · Guarded",
                        "Practice staying in a conversation that feels uncomfortable.")
            case .conflictAvoidance:
                return ("Communication Lab · How to Fight Fair",
                        "Learn Gottman's repair attempts before your next hard conversation.")
            case .overPursuit:
                return ("Face to Face Sim · Distracted",
                        "Practice holding your ground when someone isn't giving you full attention.")
            case .vulnerabilityBlock:
                return ("Voice Trainer · Warmth Calibration",
                        "Practice saying something real out loud and hearing how it actually lands.")
            case .communicationBreakdown:
                return ("Communication Lab · Repair Attempts",
                        "A short lesson on how to reopen a closed conversation.")
            case .situationshipConfusion:
                return ("Face to Face Sim · The DTR Talk",
                        "Practice the define-the-relationship conversation in a safe space first.")
            case .endingAvoidance:
                return ("Face to Face Sim · The Last Conversation",
                        "Practice saying what you need to say before you say it for real.")
            case .firstImpressionNerves:
                return ("First Impression Lab",
                        "Five 30-second cold opens to build confidence before your date.")
            case .rejectionProcessing:
                return ("Breakup Recovery",
                        "A gentler space when you're processing rejection or loss.")
            }
        }
    }

    enum Target: Equatable {
        case faceToFaceSim(personality: SimPersonality?, mode: SimMode, environment: SimEnvironment? = nil)
        case communicationLab
        case relationshipCommLab
        case voiceTrainer
        case breakupRecovery
        case firstImpressionLab
    }

    // MARK: - Parser
    // Cyrano's reply output looks like:
    //   [json array of replies]
    //   ---
    //   PATTERN: anxious_spiral
    //   EXERCISE: Face to Face Sim · Overthinker
    //   BLURB: Practice staying present...
    // The "---" block is optional. Returns the JSON portion plus an optional
    // suggestion. A trailing "---" with no recognizable pattern is dropped.
    static func parse(from raw: String) -> (clean: String, suggestion: CyranoExerciseSuggestion?) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = trimmed.range(of: "\n---") ?? trimmed.range(of: "---", options: [.backwards]) else {
            return (trimmed, nil)
        }
        let jsonPart  = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix    = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let suggestion = parseSuggestionBlock(suffix)
        return (jsonPart.isEmpty ? trimmed : jsonPart, suggestion)
    }

    private static func parseSuggestionBlock(_ block: String) -> CyranoExerciseSuggestion? {
        var pattern: PatternKind?
        var title = ""
        var blurb = ""
        for line in block.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces).uppercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            switch key {
            case "PATTERN":
                let normalized = value
                    .lowercased()
                    .replacingOccurrences(of: " ", with: "_")
                    .replacingOccurrences(of: "-", with: "_")
                pattern = PatternKind(rawValue: normalized)
            case "EXERCISE": title = value
            case "BLURB":    blurb = value
            default: break
            }
        }
        guard let p = pattern else { return nil }
        let fallback = p.defaultExercise
        return CyranoExerciseSuggestion(
            pattern: p,
            title: title.isEmpty ? fallback.title : title,
            blurb: blurb.isEmpty ? fallback.blurb : blurb
        )
    }
}

// MARK: - Dismissed tracking (per-day)

enum CyranoSuggestionDismissals {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func key() -> String {
        "cyrano.dismissed.\(formatter.string(from: Date()))"
    }

    static func dismissed(today: CyranoExerciseSuggestion.PatternKind) -> Bool {
        let arr = UserDefaults.standard.stringArray(forKey: key()) ?? []
        return arr.contains(today.rawValue)
    }

    static func markDismissed(_ pattern: CyranoExerciseSuggestion.PatternKind) {
        var arr = UserDefaults.standard.stringArray(forKey: key()) ?? []
        if !arr.contains(pattern.rawValue) {
            arr.append(pattern.rawValue)
            UserDefaults.standard.set(arr, forKey: key())
        }
    }
}

// MARK: - Suggestion Card View

struct CyranoExerciseSuggestionCard: View {
    let suggestion: CyranoExerciseSuggestion
    let onOpen: () -> Void
    let onDismiss: () -> Void
    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(LinearGradient.accent).frame(width: 32, height: 32)
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("This looks like \(suggestion.pattern.prettyName).")
                        .font(RWF.cap(11))
                        .foregroundStyle(LinearGradient.accent)
                        .tracking(0.6)
                    Text(suggestion.title)
                        .font(RWF.head(15))
                        .foregroundColor(.rwTextPrimary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            Text(suggestion.blurb)
                .font(RWF.body(14))
                .foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onOpen()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("Open exercise").font(RWF.cap(13))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(LinearGradient.accent)
                    .clipShape(Capsule())
                    .shadow(color: Color.rwAccent.opacity(0.25), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(SBS())

                Button {
                    CyranoSuggestionDismissals.markDismissed(suggestion.pattern)
                    onDismiss()
                } label: {
                    Text("Not now")
                        .font(RWF.cap(13))
                        .foregroundColor(.rwTextSecondary)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Color.rwSurface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.rwBorder, lineWidth: 1))
                }
                .buttonStyle(SBS())
            }
        }
        .padding(SP.lg)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(
            RoundedRectangle(cornerRadius: RR.xl)
                .stroke(LinearGradient.accent.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.rwAccent.opacity(0.10), radius: 18, x: 0, y: 6)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 10)
        .onAppear {
            // Gentle 0.3s delayed entrance so it doesn't compete with the
            // user reading the replies above it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    visible = true
                }
            }
        }
    }
}

// MARK: - Suggestion target → presentable view

struct CyranoExerciseHost: View {
    let suggestion: CyranoExerciseSuggestion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // Each branch returns a presentable view. FaceToFaceSimView's mode +
        // personality preselection isn't a deep-link param yet (left as a
        // follow-up); the host opens the picker and the user confirms.
        switch suggestion.target {
        case .faceToFaceSim:
            FaceToFaceSimView()
        case .communicationLab:
            NavigationView { CommunicationLabView() }
        case .relationshipCommLab:
            NavigationView { RelCommunicationLab() }
        case .voiceTrainer:
            NavigationView { VoiceConfidenceTrainerView() }
        case .breakupRecovery:
            NavigationView { BreakupRecoveryView() }
        case .firstImpressionLab:
            NavigationView { FirstImpressionLabView() }
        }
    }
}
