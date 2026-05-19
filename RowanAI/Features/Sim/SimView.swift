import SwiftUI
import Combine

// MARK: - The Sim — Entry / Picker (Build 1 Step 5)

struct SimView: View {
    @State private var selectedAvatar: SimAvatar = SimAvatars.all[0]
    @State private var selectedEnvironment: SimEnvironment = .coffeeShop
    @State private var selectedPersonality: SimPersonality = .guarded
    @State private var mode: SimMode = SimMode.auto(for: AuthService.shared.currentUser?.relationshipStatus)
    @State private var showBrief = false
    // Bumped on every "Try Again" so the fullScreenCover remounts a fresh
    // flow with the picker's same settings (same avatar/env/personality).
    @State private var briefSession = 0
    @State private var showPaywall = false
    @State private var paywallReason: PaywallView.PaywallReason = .upgrade
    @State private var replayTutorial = false

    private var availableAvatars: [SimAvatar] {
        StoreManager.shared.isPro ? SimAvatars.all : SimAvatars.all.filter { $0.isFreeTier }
    }

    private var availableEnvironments: [SimEnvironment] {
        StoreManager.shared.isPro ? SimEnvironment.allCases : [.coffeeShop, .firstDate]
    }

    private var availablePersonalities: [SimPersonality] {
        StoreManager.shared.isPro
            ? SimPersonality.allCases
            : [.guarded, .overthinker, .socialButterfly]
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    hero
                    modeSwitcher
                    avatarPicker
                    environmentPicker
                    personalityPicker
                    Spacer().frame(height: 24)
                    RWButton("Start Session", icon: "play.fill") {
                        // Freemium taste-test: 2 lifetime free sessions with
                        // real ElevenLabs voice, then paywall. Tracking of the
                        // counter happens inside SimSessionView's .task so
                        // a user who taps Start but never actually loads the
                        // session view doesn't get charged.
                        if StoreManager.shared.canStartFreeSim() {
                            showBrief = true
                        } else {
                            paywallReason = .simSessionsLimit
                            showPaywall = true
                        }
                    }
                        .padding(.horizontal, SP.lg)
                    if !StoreManager.shared.isPro {
                        let remaining = StoreManager.shared.sessionsRemainingForFreeTier()
                        let total = StoreManager.freeSimSessionLimit
                        VStack(spacing: 4) {
                            Text("\(remaining) of \(total) free \(total == 1 ? "session" : "sessions") remaining")
                                .font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                            Button("Unlock unlimited sessions + all avatars") {
                                paywallReason = .upgrade
                                showPaywall = true
                            }
                                .font(RWF.cap()).foregroundColor(.rwAccent)
                        }
                    }
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, SP.lg).padding(.top, 12)
            }
            .rwBG()
            .navigationTitle("The Sim")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(isPresented: $showBrief) {
                SimPreSessionView(
                    avatar: selectedAvatar,
                    environment: selectedEnvironment,
                    personality: selectedPersonality,
                    mode: mode,
                    returnToPicker: { showBrief = false },
                    restartSession: {
                        // Dismiss the entire stack, then re-present after the
                        // dismissal animation lands. .id() forces a fresh mount
                        // so all per-session state (transcript, meter, timer)
                        // resets cleanly on retry.
                        showBrief = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            briefSession += 1
                            showBrief = true
                        }
                    }
                )
                .id(briefSession)
            }
            .sheet(isPresented: $showPaywall) { PaywallView(reason: paywallReason) }
            .tutorial(.sim, forceShow: $replayTutorial)
        }
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(mode.color)
                    Text(mode.headerLabel.uppercased())
                        .font(RWF.micro())
                        .foregroundColor(mode.color)
                        .tracking(1.6)
                }
                Text("Pick your scene.").font(RWF.display(26)).foregroundColor(.rwTextPrimary)
                Text(modeSubtitle)
                    .font(RWF.body()).foregroundColor(.rwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            TutorialReplayButton(id: .sim, forceShow: $replayTutorial)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var modeSubtitle: String {
        switch mode {
        case .single:        return "Real conversations are practiced, not improvised."
        case .relationship:  return "Practice the conversations that actually move your relationship forward."
        case .complicated:   return "Practice saying the hard things — closure, definition, exit, repair."
        }
    }

    // Manual mode override — user can practice any mode regardless of status.
    private var modeSwitcher: some View {
        VStack(alignment: .leading, spacing: 8) {
            RWSectionLabel("PRACTICE MODE")
            HStack(spacing: 6) {
                ForEach(SimMode.allCases) { m in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { mode = m }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: m.icon).font(.system(size: 11, weight: .medium, design: .rounded))
                            Text(m.shortLabel).font(RWF.cap(12))
                        }
                        .foregroundColor(mode == m ? .white : .rwTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(mode == m ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.rwSurface))
                        .clipShape(RoundedRectangle(cornerRadius: RR.md))
                        .overlay(RoundedRectangle(cornerRadius: RR.md)
                            .stroke(mode == m ? Color.clear : Color.rwBorder, lineWidth: 1))
                    }
                    .buttonStyle(SBS())
                }
            }
        }
    }

    private var avatarPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            RWSectionLabel("AVATAR")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(SimAvatars.all) { avatar in
                        AvatarThumb(
                            avatar: avatar,
                            isSelected: selectedAvatar.id == avatar.id,
                            isLocked: !availableAvatars.contains(where: { $0.id == avatar.id })
                        ) {
                            if availableAvatars.contains(where: { $0.id == avatar.id }) {
                                selectedAvatar = avatar
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } else {
                                showPaywall = true
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var environmentPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            RWSectionLabel("ENVIRONMENT")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(SimEnvironment.allCases) { env in
                    let locked = !availableEnvironments.contains(env)
                    EnvironmentCard(env: env,
                                    isSelected: selectedEnvironment == env,
                                    isLocked: locked) {
                        if locked { showPaywall = true }
                        else {
                            selectedEnvironment = env
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                }
            }
        }
    }

    private var personalityPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            RWSectionLabel("PERSONALITY")
            VStack(spacing: 8) {
                ForEach(SimPersonality.allCases) { person in
                    let locked = !availablePersonalities.contains(person)
                    PersonalityRow(personality: person,
                                   isSelected: selectedPersonality == person,
                                   isLocked: locked) {
                        if locked { showPaywall = true }
                        else {
                            selectedPersonality = person
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Picker Cells

private struct AvatarThumb: View {
    let avatar: SimAvatar
    let isSelected: Bool
    let isLocked: Bool
    let onTap: () -> Void

    @State private var testing = false
    @State private var testError: String? = nil

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(hex: avatar.gradientStart), Color(hex: avatar.gradientEnd)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 76, height: 76)
                            .opacity(isLocked ? 0.4 : 1)
                        Text(String(avatar.name.prefix(1)))
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                                .offset(x: 26, y: 26)
                        }
                    }
                    .overlay(Circle().stroke(isSelected ? Color.rwAccent : .clear, lineWidth: 3))

                    // Audition the voice without committing to a session.
                    // Hidden when the avatar is locked — locked avatars
                    // require Pro to even hear.
                    if !isLocked {
                        speakerButton
                            .offset(x: 4, y: 4)
                    }
                }
                Text(avatar.name)
                    .font(RWF.cap())
                    .foregroundColor(isSelected ? .rwAccent : .rwTextSecondary)
                if let testError {
                    Text(testError)
                        .font(RWF.micro())
                        .foregroundColor(.rwDanger)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 84)
                }
            }
        }
        .buttonStyle(SBS())
    }

    private var speakerButton: some View {
        Button {
            // Don't trigger the parent button's selection — the speaker is
            // a sibling action.
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { await runTest() }
        } label: {
            ZStack {
                Circle()
                    .fill(testing ? Color.rwAccent : Color(hex: "0D0D0D"))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                if testing {
                    ProgressView().tint(.white).scaleEffect(0.55)
                } else {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(SBS())
        .disabled(testing)
        .accessibilityLabel("Test \(avatar.name)'s voice")
    }

    @MainActor
    private func runTest() async {
        guard !testing else { return }
        testing = true
        testError = nil
        defer { testing = false }
        if let err = await ElevenLabsService.shared.testVoice(avatar: avatar) {
            testError = err
            // Auto-clear after a few seconds so the cell isn't permanently
            // marked as failed — user can retry.
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { testError = nil }
        }
    }
}

private struct EnvironmentCard: View {
    let env: SimEnvironment
    let isSelected: Bool
    let isLocked: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: env.icon)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(isSelected ? .white : env.color)
                        .frame(width: 36, height: 36)
                        .background(isSelected ? env.color : env.color.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: RR.sm))
                    Spacer()
                    if isLocked {
                        Image(systemName: "lock.fill").font(.system(size: 11, design: .rounded)).foregroundColor(.rwTextMuted)
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(env.color)
                    }
                }
                Text(env.rawValue).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                if let limit = env.timeLimitSeconds {
                    Text("\(limit / 60) min").font(RWF.cap(11)).foregroundColor(.rwTextMuted)
                } else {
                    Text("No time limit").font(RWF.cap(11)).foregroundColor(.rwTextMuted)
                }
            }
            .padding(SP.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? env.color.opacity(0.06) : Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg)
                .stroke(isSelected ? env.color.opacity(0.4) : Color.rwBorder,
                        lineWidth: isSelected ? 1.5 : 1))
            .opacity(isLocked ? 0.6 : 1)
        }
        .buttonStyle(SBS())
    }
}

private struct PersonalityRow: View {
    let personality: SimPersonality
    let isSelected: Bool
    let isLocked: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: personality.icon)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .white : personality.difficulty.color)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? personality.difficulty.color : personality.difficulty.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(personality.rawValue).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                        Text(personality.difficulty.rawValue.uppercased())
                            .font(RWF.micro())
                            .foregroundColor(personality.difficulty.color)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(personality.difficulty.color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text(personality.coachingBrief)
                        .font(RWF.body(12)).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if isLocked {
                    Image(systemName: "lock.fill").font(.system(size: 14, design: .rounded)).foregroundColor(.rwTextMuted)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(personality.difficulty.color)
                }
            }
            .padding(SP.md)
            .background(isSelected ? personality.difficulty.color.opacity(0.06) : Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg)
                .stroke(isSelected ? personality.difficulty.color.opacity(0.4) : Color.rwBorder,
                        lineWidth: isSelected ? 1.5 : 1))
            .opacity(isLocked ? 0.6 : 1)
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Pre-Session Brief (Step 5c)

struct SimPreSessionView: View {
    let avatar: SimAvatar
    let environment: SimEnvironment
    let personality: SimPersonality
    let mode: SimMode
    // Closures from SimView. returnToPicker collapses the entire
    // fullScreenCover stack; restartSession relaunches the flow with the
    // picker's same settings (used by debrief's "Try Again").
    var returnToPicker: () -> Void = {}
    var restartSession: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var coachingTip: String = ""
    @State private var loading = true
    @State private var showCoach = false

    var body: some View {
        ZStack {
            Color.rwBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    header
                    contextCard
                    coachingCard
                    winConditionCard
                    Spacer().frame(height: 24)
                    RWButton("Start Session", icon: "play.fill") { showCoach = true }
                        .padding(.horizontal, SP.lg)
                    Button("Cancel") { returnToPicker() }
                        .font(RWF.cap()).foregroundColor(.rwTextMuted)
                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, SP.lg).padding(.top, 32)
            }
        }
        .task { await loadCoachingTip() }
        .fullScreenCover(isPresented: $showCoach) {
            PreSessionCoachView(
                avatar: avatar,
                environment: environment,
                personality: personality,
                mode: mode,
                returnToPicker: returnToPicker,
                restartSession: restartSession
            )
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(mode.color)
                Text(mode.headerLabel.uppercased())
                    .font(RWF.micro())
                    .foregroundColor(mode.color)
                    .tracking(1.5)
            }
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: avatar.gradientStart), Color(hex: avatar.gradientEnd)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                Text(String(avatar.name.prefix(1)))
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            Text("\(avatar.name) · \(environment.displayTitle(for: mode))")
                .font(RWF.title(20)).foregroundColor(.rwTextPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                badge(personality.rawValue, color: personality.difficulty.color)
                badge(personality.difficulty.rawValue, color: personality.difficulty.color, filled: true)
            }
        }
    }

    private func badge(_ text: String, color: Color, filled: Bool = false) -> some View {
        Text(text.uppercased())
            .font(RWF.micro())
            .foregroundColor(filled ? .white : color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(filled ? color : color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var contextCard: some View {
        RWCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("The scene", systemImage: environment.icon)
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                Text(environment.openingScene(for: mode))
                    .font(RWF.body()).foregroundColor(.rwTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var coachingCard: some View {
        RWCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Cyrano's tip", systemImage: "sparkles")
                    .font(RWF.cap()).foregroundColor(.rwAccent)
                if loading && coachingTip.isEmpty {
                    HStack { ProgressView(); Text("Reading the room…").font(RWF.body(14)).foregroundColor(.rwTextMuted) }
                } else {
                    Text(coachingTip.isEmpty ? personality.coachingBrief : coachingTip)
                        .font(RWF.body()).foregroundColor(.rwTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var winConditionCard: some View {
        RWCard {
            VStack(alignment: .leading, spacing: 6) {
                Label("What the win looks like", systemImage: "flag.checkered")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                Text(mode.winCondition.replacingOccurrences(of: "Win condition: ", with: ""))
                    .font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func loadCoachingTip() async {
        loading = true
        defer { loading = false }
        guard AISettings.shared.isEnabled else { return }
        let modeBrief: String = {
            switch mode {
            case .single:
                return "Mode: SINGLE — practicing meeting someone new and holding interest."
            case .relationship:
                let p = AuthService.shared.currentUser?.partnerName ?? "their partner"
                return """
                Mode: RELATIONSHIP — practicing with their own partner (\(p)) on a real relationship scenario.
                Coach on: leading with feelings not blame, staying curious, listening before talking, repair attempts.
                Name the scenario, the skill, one specific tip, and what the win looks like today.
                """
            case .complicated:
                return """
                Mode: IT'S COMPLICATED — practicing a hard scenario with someone from their unresolved past.
                Coach on: saying hard things kindly, ending with dignity, staying grounded when emotions are high, owning closure (it comes from them, not the other person).
                """
            }
        }()
        let role = """
        YOUR ROLE NOW: Pre-session coach for The Sim.
        The user is about to practice with a \(personality.rawValue) personality in a \(environment.displayTitle(for: mode)) setting.
        \(modeBrief)
        Personality summary: \(personality.coachingBrief)
        Scene: \(environment.openingScene(for: mode))
        Give one specific, actionable tip in 2-3 sentences. No preamble. Address the user directly. Sound like a smart friend.
        """
        do {
            let raw = try await Claude.shared.send(
                system: role,
                user: "What should they focus on for this session?",
                max: 220
            )
            coachingTip = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            coachingTip = personality.coachingBrief
        }
    }
}
