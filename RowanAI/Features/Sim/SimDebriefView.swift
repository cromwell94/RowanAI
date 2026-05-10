import SwiftUI

// MARK: - Post-Session Debrief (Step 5f)

struct SimDebriefView: View {
    let avatar: SimAvatar
    let environment: SimEnvironment
    let personality: SimPersonality
    let mode: SimMode
    let messages: [SimTurn]
    let finalScore: Int
    let endReason: SimSessionView.EndReason
    // Closures from SimView. "Done" calls returnToPicker which
    // collapses the entire fullScreenCover stack; "Try Again" calls
    // restartSession which relaunches the flow with the same picker settings.
    var returnToPicker: () -> Void = {}
    var restartSession: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var cyranoAnalysis: String = ""
    @State private var loadingAnalysis = true

    private var grade: Grade { Grade.forScore(finalScore, ended: endReason) }

    enum Grade: String {
        case rookie       = "Rookie"
        case gettingThere = "Getting There"
        case solid        = "Solid"
        case strong       = "Strong"
        case unshakeable  = "Unshakeable"

        var color: Color {
            switch self {
            case .rookie:       return Color(hex: "9BA8BF")
            case .gettingThere: return Color(hex: "F59E0B")
            case .solid:        return Color(hex: "5B8DEF")
            case .strong:       return Color(hex: "00BFB3")
            case .unshakeable:  return Color(hex: "E8356D")
            }
        }

        static func forScore(_ score: Int, ended: SimSessionView.EndReason) -> Grade {
            if ended == .disengaged { return .rookie }
            switch score {
            case ..<35:  return .rookie
            case ..<55:  return .gettingThere
            case ..<70:  return .solid
            case ..<85:  return .strong
            default:     return .unshakeable
            }
        }
    }

    var body: some View {
        ZStack {
            Color.rwBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    header
                    whatHappenedCard
                    psychologyCard
                    playbookCard
                    actionRow
                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, SP.lg).padding(.top, 60)
            }
            VStack {
                HStack {
                    Spacer()
                    // Done — collapses the entire flow (debrief → session →
                    // coach → brief) back to the picker via returnToPicker.
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        returnToPicker()
                    } label: {
                        ZStack {
                            Circle().fill(Color.rwCard)
                                .frame(width: 32, height: 32)
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.rwTextSecondary)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Done")
                    .padding(.top, 50).padding(.trailing, 12)
                }
                Spacer()
            }
        }
        .task { await loadAnalysis() }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color.rwBorder, lineWidth: 6).frame(width: 124, height: 124)
                Circle()
                    .trim(from: 0, to: CGFloat(finalScore) / 100.0)
                    .stroke(grade.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 124, height: 124)
                VStack(spacing: 2) {
                    Text("\(finalScore)")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.rwTextPrimary)
                    Text(grade.rawValue.uppercased())
                        .font(RWF.micro()).foregroundColor(grade.color).tracking(1.2)
                }
            }
            Text(headlineForReason).font(RWF.title(20)).foregroundColor(.rwTextPrimary)
            Text("\(avatar.name) · \(environment.displayTitle(for: mode)) · \(personality.rawValue)")
                .font(RWF.cap()).foregroundColor(.rwTextMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(mode.color)
                Text(mode.headerLabel.uppercased())
                    .font(RWF.micro())
                    .foregroundColor(mode.color)
                    .tracking(1.4)
            }
        }
    }

    private var headlineForReason: String {
        switch endReason {
        case .userEnded:   return "Session complete."
        case .timeUp:      return "Time's up."
        case .disengaged:  return "They walked away."
        }
    }

    private var whatHappenedCard: some View {
        RWCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("What happened", systemImage: "sparkles")
                    .font(RWF.cap()).foregroundColor(.rwAccent)
                if loadingAnalysis && cyranoAnalysis.isEmpty {
                    HStack {
                        ProgressView()
                        Text("Cyrano is reading the session…")
                            .font(RWF.body(14)).foregroundColor(.rwTextMuted)
                    }
                } else {
                    Text(cyranoAnalysis.isEmpty
                         ? "You showed up, you tried, you got data. Run it again with one specific change in mind."
                         : cyranoAnalysis)
                        .font(RWF.body()).foregroundColor(.rwTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var psychologyCard: some View {
        RWCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("The psychology", systemImage: "brain.head.profile")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                Text(personality.intelligenceBrief)
                    .font(RWF.body()).foregroundColor(.rwTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var playbookCard: some View {
        RWCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("The playbook", systemImage: "book.fill")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                ForEach(personality.playbook, id: \.self) { tactic in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(Color.rwAccent.opacity(0.5))
                            .frame(width: 5, height: 5).padding(.top, 7)
                        Text(tactic).font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var actionRow: some View {
        VStack(spacing: 10) {
            // Try again — relaunches the flow with the picker's same settings.
            RWButton("Try again", icon: "arrow.clockwise") {
                restartSession()
            }
            // Change settings — bails the entire flow back to the picker so
            // the user can adjust avatar/environment/personality.
            Button("Change settings") { returnToPicker() }
                .font(RWF.cap()).foregroundColor(.rwTextMuted)
        }
        .padding(.horizontal, SP.lg)
    }

    private func loadAnalysis() async {
        loadingAnalysis = true
        defer { loadingAnalysis = false }
        guard AISettings.shared.isEnabled, !messages.isEmpty else { return }
        let transcript = messages.suffix(20).map {
            ($0.role == .user ? "[USER]: " : "[\(avatar.name.uppercased())]: ") + $0.text
        }.joined(separator: "\n")

        // Mode-specific debrief lens — the questions Cyrano evaluates against.
        let modeLens: String = {
            switch mode {
            case .single:
                return "Score the user on attraction-building: did they earn attention, ask good questions, hold their ground, leave the avatar wanting more?"
            case .relationship:
                return """
                Score the user using Gottman's framework:
                - Did they use blame or curiosity?
                - Did they stay regulated or escalate?
                - Did they listen or just wait to talk?
                - Were any of the Four Horsemen present (criticism, contempt, defensiveness, stonewalling)?
                - Did they make / receive bids for connection or repair attempts?
                Then: one specific thing to try differently next time.
                """
            case .complicated:
                return """
                Score the user on emotional-intelligence under pressure:
                - Did they say what they actually needed to say?
                - Did they stay kind even when it was hard?
                - Did they avoid the truth or lean into it?
                - Reframe closure: it comes from them, not from the other person.
                Then: one thing they did well and one thing to work on.
                """
            }
        }()

        let role = """
        YOUR ROLE NOW: Post-session coach for The Sim.
        The user just practiced (\(mode.headerLabel)) with a \(personality.rawValue) personality at "\(environment.displayTitle(for: mode))".
        Final engagement score: \(finalScore)/100. Outcome: \(endReason).
        \(modeLens)
        Read this transcript and write the user a short debrief — 3-4 sentences. Plain prose, no headers, no bullet lists. Smart-friend tone, not therapist.
        """
        do {
            let raw = try await Claude.shared.send(
                system: role,
                user: transcript,
                max: 350
            )
            cyranoAnalysis = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            cyranoAnalysis = ""
        }
    }
}
