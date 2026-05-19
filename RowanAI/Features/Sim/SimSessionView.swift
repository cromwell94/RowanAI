import SwiftUI
import Combine

// MARK: - Sim Session — Live Conversation (Step 5d, 5e)

struct SimSessionView: View {
    let avatar: SimAvatar
    let environment: SimEnvironment
    let personality: SimPersonality
    let mode: SimMode

    // Closures threaded down from SimView so the X button can collapse
    // the entire fullScreenCover chain (brief → coach → session → debrief) back
    // to the picker, and so debrief's "Try Again" can relaunch a fresh session
    // with the picker's current settings.
    let returnToPicker: () -> Void
    let restartSession: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var meter: EngagementMeter
    @State private var messages: [SimTurn] = []
    @State private var partialTranscript = ""
    @State private var isHoldingMic = false
    @State private var isThinking = false
    @State private var avatarPulse = false
    @State private var sessionEnded = false
    @State private var endReason: EndReason = .userEnded
    @State private var showDebrief = false
    @State private var showEndAlert = false
    @State private var permissionRequested = false
    @State private var avatarError = false
    @State private var avatarErrorReason: String? = nil

    // Voice connection (LiveKit) — non-nil when the most recent connect attempt
    // failed. Surfaced as a tap-to-retry banner at the top of the session view.
    @State private var voiceConnectionError: String? = nil

    // Time tracking
    @State private var elapsed: Int = 0
    @State private var timerCancellable: AnyCancellable? = nil

    // Mid-session interruption
    @State private var pendingInterruption: String? = nil
    @State private var nextInterruptionAt: Int = 60   // seconds — set on appear

    // Speech recognition
    @State private var speech = SpeechService.shared
    @State private var speechAuthorized = false

    init(avatar: SimAvatar,
         environment: SimEnvironment,
         personality: SimPersonality,
         mode: SimMode = .single,
         returnToPicker: @escaping () -> Void = {},
         restartSession: @escaping () -> Void = {}) {
        self.avatar = avatar
        self.environment = environment
        self.personality = personality
        self.mode = mode
        self.returnToPicker = returnToPicker
        self.restartSession = restartSession
        _meter = State(initialValue: EngagementMeter(personality: personality))
    }

    var body: some View {
        ZStack {
            // Cinematic backdrop — dark with a subtle accent-tinted halo behind
            // the avatar. Status bar text inverts to light via .preferredColorScheme.
            LinearGradient.cinematic.ignoresSafeArea()
            RadialGradient(colors: [Color(hex: avatar.gradientStart).opacity(0.18), .clear],
                           center: .top, startRadius: 0, endRadius: 380)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                avatarStage
                transcript
                inputBar
            }
            if let interruption = pendingInterruption {
                InterruptionBanner(text: interruption)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 80)
                    .padding(.horizontal, SP.lg)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            VStack(spacing: 6) {
                if LiveKitService.shared.isConnecting {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text("Connecting voice...").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                if let detail = voiceConnectionError {
                    voiceErrorBanner(detail: detail)
                }
            }
            .padding(.top, 8)
        }
        .task {
            speechAuthorized = await speech.requestAuthorization()
            permissionRequested = true
            scheduleFirstInterruption()
            startTimer()
            // Burn one lifetime free-tier credit per session start (not per
            // avatar reply). The picker's canStartFreeSim() gate guarantees
            // we only get here with credits remaining. Pro users and testers
            // with the debug override don't consume the counter.
            if !StoreManager.shared.isPro && !StoreManager.shared.debugForceElevenLabsVoice {
                StoreManager.shared.trackSimSessionStarted()
            }
            await primeOpening()
        }
        .task { await connectLiveKit() }
        .onDisappear {
            timerCancellable?.cancel()
            speech.stop()
            ElevenLabsService.shared.stop()
            AppleTTSService.shared.stop()
            Task { await LiveKitService.shared.disconnect() }
        }
        .fullScreenCover(isPresented: $showDebrief) {
            SimDebriefView(
                avatar: avatar,
                environment: environment,
                personality: personality,
                mode: mode,
                messages: messages,
                finalScore: meter.score,
                endReason: endReason,
                returnToPicker: returnToPicker,
                restartSession: restartSession
            )
        }
        // X-button confirmation. Buttons:
        //   "End Session" — runs endSession(.userEnded), which presents the
        //   debrief above the session view (results are preserved per spec).
        //   "Keep Going" — destructive=false, simply dismisses the alert.
        .alert("End Session?",
               isPresented: $showEndAlert) {
            Button("Keep Going", role: .cancel) { }
            Button("End Session", role: .destructive) {
                endSession(.userEnded)
            }
        } message: {
            Text("Your progress will be saved for the debrief.")
        }
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            // Top-left close. 44×44 tap target, with an inset 36×36 visual
            // chrome to keep the existing minimal look. Behavior:
            //   - sessionEnded → returnToPicker() (collapses the whole stack)
            //   - active session → confirmation alert before tearing down
            // contentShape ensures the full 44×44 frame is hit-testable, not
            // just the visual circle.
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if sessionEnded {
                    returnToPicker()
                } else {
                    showEndAlert = true
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(Color.rwInkBorder, lineWidth: 1))
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.rwInkText)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(sessionEnded ? "Close session" : "End session")
            VStack(alignment: .leading, spacing: 1) {
                Text(avatar.name)
                    .font(RWF.head(15)).foregroundColor(.rwInkText)
                Text(environment.displayTitle(for: mode))
                    .font(RWF.cap(11)).foregroundColor(.rwInkTextMuted).tracking(1.0)
                    .lineLimit(1)
            }
            Spacer()
            timerBadge
        }
        .padding(.top, 60).padding(.leading, 20).padding(.trailing, SP.lg).padding(.bottom, 12)
    }

    private var timerBadge: some View {
        Group {
            if let limit = environment.timeLimitSeconds {
                let remaining = max(0, limit - elapsed)
                HStack(spacing: 5) {
                    Image(systemName: "clock.fill").font(.system(size: 10, weight: .medium, design: .rounded))
                    Text(format(remaining))
                        .font(RWF.mono(11))
                        .contentTransition(.numericText())
                }
                .foregroundColor(remaining < 30 ? .rwAccent : .rwInkText)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Color.white.opacity(0.10))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.rwInkBorder, lineWidth: 1))
            } else {
                Text(format(elapsed))
                    .font(RWF.mono(11)).foregroundColor(.rwInkTextMuted)
                    .contentTransition(.numericText())
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
            }
        }
    }

    private func format(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: Avatar stage (top 40%)

    private var avatarStage: some View {
        VStack(spacing: 14) {
            ZStack {
                // Outer glow ring — gives the avatar weight on the dark stage.
                Circle()
                    .fill(Color(hex: avatar.gradientStart).opacity(0.4))
                    .frame(width: 240, height: 240)
                    .blur(radius: 50)
                    .scaleEffect(avatarPulse ? 1.04 : 0.96)

                // Avatar disc — placeholder until D-ID photos land. Pulse +
                // waveform make it feel alive even without a portrait.
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: avatar.gradientStart), Color(hex: avatar.gradientEnd)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 184, height: 184)
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1.5))
                    .scaleEffect(avatarPulse ? 1.02 : 1.0)
                    .shadow(color: Color.black.opacity(0.5), radius: 18, x: 0, y: 12)

                Text(String(avatar.name.prefix(1)))
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 2)

                if meter.isWarning {
                    Circle()
                        .stroke(Color.rwAccent.opacity(0.5), lineWidth: 2)
                        .frame(width: 204, height: 204)
                        .scaleEffect(avatarPulse ? 1.06 : 1.0)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                    avatarPulse.toggle()
                }
            }

            // Speaking waveform — fires while Cyrano is generating or the
            // avatar is voicing the response (both gated on isThinking).
            AvatarWaveform(active: isThinking,
                           color: Color(hex: avatar.gradientStart))
                .frame(height: 18)

            if meter.isWarning {
                Text("They're starting to drift…")
                    .font(RWF.cap(12))
                    .foregroundColor(.rwAccent)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.rwAccent.opacity(0.14))
                    .clipShape(Capsule())
            }
        }
        .padding(.top, 8).padding(.bottom, 20)
    }

    // MARK: Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(messages) { msg in
                        bubble(msg)
                            .id(msg.id)
                    }
                    if isThinking {
                        HStack {
                            TypingIndicator(color: Color(hex: avatar.gradientStart))
                            Spacer()
                        }
                        .padding(.horizontal, SP.lg)
                    }
                    if avatarError && !isThinking {
                        avatarErrorPill
                            .padding(.horizontal, SP.lg)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    Spacer().frame(height: 8)
                }
                .padding(.vertical, 8)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // Inline error pill — surfaces network/auth failures from Claude and
    // lets the user re-trigger the avatar's turn without leaving the session.
    // `avatarErrorReason` (when set) replaces the default copy so debugging
    // a stuck Sim from the simulator console isn't the only way to see why.
    private var avatarErrorPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.rwAccent)
            Text(avatarErrorReason ?? "Cyrano is unavailable right now — try again in a moment.")
                .font(RWF.body(13)).foregroundColor(.rwInkText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                retryAvatarTurn()
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(RWF.cap(12)).foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(LinearGradient.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(SBS())
        }
        .padding(SP.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: RR.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RR.md, style: .continuous)
            .stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    // Top-of-screen banner shown when the LiveKit voice handshake fails.
    // Tap reruns connectLiveKit(). Two-line layout: short headline + raw
    // error detail so we can diagnose without the Xcode console.
    private func voiceErrorBanner(detail: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { await connectLiveKit() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "waveform.slash")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.rwAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Voice connection failed. Tap to retry.")
                        .font(RWF.body(13)).foregroundColor(.rwInkText)
                    Text(detail)
                        .font(RWF.cap(11)).foregroundColor(.rwInkTextMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.rwInkText)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RR.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: RR.md, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1))
            .padding(.horizontal, SP.lg)
        }
        .buttonStyle(SBS())
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func bubble(_ msg: SimTurn) -> some View {
        HStack {
            if msg.role == .user { Spacer(minLength: 50) }
            Text(msg.text)
                .font(RWF.body(15))
                .foregroundColor(.white)
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(
                    Group {
                        if msg.role == .user {
                            AnyView(LinearGradient.accent)
                        } else {
                            AnyView(Color.white.opacity(0.10))
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: RR.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: RR.lg, style: .continuous)
                        .stroke(msg.role == .user ? Color.clear : Color.white.opacity(0.12),
                                lineWidth: 1)
                )
                .shadow(color: msg.role == .user
                        ? Color.rwAccent.opacity(0.25)
                        : Color.black.opacity(0.15),
                        radius: 10, x: 0, y: 4)
                .frame(maxWidth: 280, alignment: msg.role == .user ? .trailing : .leading)
            if msg.role == .avatar { Spacer(minLength: 50) }
        }
        .padding(.horizontal, SP.lg)
    }

    // MARK: Input

    @ViewBuilder
    private var inputBar: some View {
        if permissionRequested && !speechAuthorized {
            permissionDeniedCard
        } else {
            standardInputBar
        }
    }

    // Shown when the user has denied microphone or speech-recognition access.
    // Provides a single, obvious path to fix it (Settings deep link).
    private var permissionDeniedCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.white.opacity(0.10)).frame(width: 56, height: 56)
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundColor(.rwAccent)
            }
            Text("Microphone access needed")
                .font(RWF.head(15)).foregroundColor(.rwInkText)
            Text("The Sim uses your microphone and speech recognition. Enable both in Settings to start a session.")
                .font(RWF.body(13)).foregroundColor(.rwInkTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SP.lg)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open Settings", systemImage: "gearshape.fill")
                    .font(RWF.cap()).foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(LinearGradient.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(SBS())
        }
        .padding(.vertical, 20)
        .padding(.bottom, 20)
    }

    private var standardInputBar: some View {
        VStack(spacing: 12) {
            if isHoldingMic {
                Text(speech.transcript.isEmpty ? "Listening…" : speech.transcript)
                    .font(RWF.body(14)).foregroundColor(.rwInkText)
                    .padding(.horizontal, SP.lg).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: RR.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: RR.md, style: .continuous)
                        .stroke(Color.rwAccent.opacity(0.4), lineWidth: 1))
                    .padding(.horizontal, SP.lg)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            ZStack {
                // Outer pulse when recording
                if isHoldingMic {
                    Circle()
                        .stroke(Color.rwAccent.opacity(0.4), lineWidth: 2)
                        .frame(width: 96, height: 96)
                        .scaleEffect(avatarPulse ? 1.15 : 1.0)
                }
                Circle()
                    .fill(isHoldingMic
                          ? AnyShapeStyle(LinearGradient.accent)
                          : AnyShapeStyle(LinearGradient.accent.opacity(0.92)))
                    .frame(width: 78, height: 78)
                    .overlay(Circle().stroke(Color.white.opacity(0.20), lineWidth: 1))
                    .scaleEffect(isHoldingMic ? 1.08 : 1.0)
                    .shadow(color: Color.rwAccent.opacity(0.5), radius: 22, x: 0, y: 10)
                Image(systemName: "mic.fill")
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }
            // Hold-to-talk. DragGesture(minimumDistance: 0) fires onChanged on
            // initial touch, onEnded on release — the cleanest hold-to-talk
            // pattern in SwiftUI without bouncing through Apple's gesture
            // sequencing combinators.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isHoldingMic { beginRecording() }
                    }
                    .onEnded { _ in endRecordingAndSubmit() }
            )
            .disabled(!speechAuthorized || isThinking || sessionEnded)
            Text(speechAuthorized ? "Hold to speak" : "Microphone access needed")
                .font(RWF.cap(11))
                .foregroundColor(.rwInkTextMuted)
                .tracking(1.0)
        }
        .padding(.bottom, 38)
    }

    // MARK: Lifecycle

    private func startTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in tick() }
    }

    private func tick() {
        guard !sessionEnded else { return }
        elapsed += 1

        // Time limit reached?
        if let limit = environment.timeLimitSeconds, elapsed >= limit {
            endSession(.timeUp)
            return
        }

        // Mid-session interruption?
        if elapsed == nextInterruptionAt, let line = environment.midSessionEvents.randomElement() {
            withAnimation { pendingInterruption = line }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation { pendingInterruption = nil }
            }
            // Schedule another later in the session
            nextInterruptionAt = elapsed + Int.random(in: 60...120)
        }

        // Silence bleed
        meter.tickIfSilent()
        if meter.didDisengage {
            endSession(.disengaged)
        }
    }

    private func scheduleFirstInterruption() {
        nextInterruptionAt = Int.random(in: 45...90)
    }

    private func primeOpening() async {
        // Have the avatar start with a brief opening line so the user has
        // something to react to. Uses Claude with the personality system prompt.
        print("[Sim] starting session for \(avatar.name)")
        guard AISettings.shared.isEnabled else {
            print("[Sim] primeOpening skipped — AISettings.isEnabled = false")
            return
        }
        isThinking = true
        defer { isThinking = false }
        let partner = AuthService.shared.currentUser?.partnerName
        let profile = Claude.userProfileBlock(forSim: true)
        let frame = """
        \(personality.systemPrompt)\(mode.systemPromptOverlay(partnerName: partner))\(profile)

        SETTING: \(environment.openingScene(for: mode))
        Open the conversation with a single short line in character — 1-2 sentences max.
        """
        do {
            let raw = try await Claude.shared.send(
                system: frame,
                user: "Begin.",
                max: 120
            )
            let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            await MainActor.run {
                let opener = SimTurn(role: .avatar, text: cleaned)
                messages.append(opener)
            }
            await speakAvatar(cleaned)
        } catch {
            print("[Sim] primeOpening failed — \(error.localizedDescription)")
            await MainActor.run {
                avatarErrorReason = "Couldn't load the opening line: \(error.localizedDescription)"
                withAnimation(.easeOut(duration: 0.2)) { avatarError = true }
            }
        }
    }

    // MARK: Voice + AI flow

    private func beginRecording() {
        guard !isHoldingMic, speechAuthorized, !isThinking, !sessionEnded else { return }
        do {
            try speech.start()
            isHoldingMic = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch {
            // surface silently — user can try again
        }
    }

    private func endRecordingAndSubmit() {
        guard isHoldingMic else { return }
        isHoldingMic = false
        // Light tap on release — confirms send to the user without overwhelming
        // the medium-impact press haptic.
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let final = speech.stop().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !final.isEmpty else { return }
        let msg = SimTurn(role: .user, text: final)
        messages.append(msg)
        meter.ingestUserMessage(final)
        Task { await submitToAvatar() }
    }

    private func submitToAvatar() async {
        guard AISettings.shared.isEnabled else { return }
        isThinking = true
        defer { isThinking = false }

        let history = messages.suffix(12).map {
            ($0.role == .user ? "[USER]: " : "[YOU]: ") + $0.text
        }.joined(separator: "\n")

        let engagementHint: String = {
            if meter.score < 25 { return "(You are about to leave — your patience is gone.)" }
            if meter.isAtRisk    { return "(You are losing interest — answers shorter, attention drifting.)" }
            if meter.score > 80  { return "(You are genuinely engaged.)" }
            return ""
        }()

        let partner = AuthService.shared.currentUser?.partnerName
        let profile = Claude.userProfileBlock(forSim: true)
        let frame = """
        \(personality.systemPrompt)\(mode.systemPromptOverlay(partnerName: partner))\(profile)

        SETTING: \(environment.openingScene(for: mode))
        \(engagementHint)

        TRANSCRIPT SO FAR:
        \(history)

        YOUR NEXT REPLY (1-3 sentences, in character, no narration, no quotes):
        """

        do {
            let raw = try await Claude.shared.send(
                system: frame,
                user: "Reply now.",
                max: 200
            )
            let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            await MainActor.run {
                let response = SimTurn(role: .avatar, text: cleaned)
                messages.append(response)
                avatarError = false
                avatarErrorReason = nil
            }
            await speakAvatar(cleaned)

            if meter.didDisengage {
                endSession(.disengaged)
            }
        } catch {
            // Surface a retry pill in the transcript instead of polluting the
            // message history with an error glyph that would survive into the
            // debrief transcript. The reason string drives the pill copy so the
            // user (and we) can see *why* the reply failed.
            print("[Sim] submitToAvatar failed — \(error.localizedDescription)")
            await MainActor.run {
                avatarErrorReason = "Reply failed: \(error.localizedDescription)"
                withAnimation(.easeOut(duration: 0.2)) { avatarError = true }
            }
        }
    }

    /// User taps "Retry" on the avatar-error pill — re-runs the model call
    /// using the same conversation state. The last user turn already lives in
    /// `messages`, so submitToAvatar picks it up unchanged.
    private func retryAvatarTurn() {
        guard !isThinking, !sessionEnded else { return }
        avatarError = false
        avatarErrorReason = nil
        Task { await submitToAvatar() }
    }

    // LiveKit voice-handshake. Extracted from the second `.task` so the
    // top-of-screen `voiceErrorBanner` can re-invoke it without recreating
    // the whole view. On failure, populates `voiceConnectionError` (which
    // drives the banner) instead of swallowing silently.
    private func connectLiveKit() async {
        do {
            let userID = try await LiveKitService.userID()
            let roomName = LiveKitService.simRoomName(avatarID: avatar.id, userID: userID)
            print("[Sim] LiveKit connection attempt: room=\(roomName)")
            await MainActor.run { voiceConnectionError = nil }
            await LiveKitService.shared.connect(roomName: roomName,
                                                displayName: avatar.name)
            print("[Sim] LiveKit connection result: success")
        } catch {
            print("[Sim] LiveKit connection result: error — \(error.localizedDescription)")
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    voiceConnectionError = error.localizedDescription
                }
            }
        }
    }

    private func speakAvatar(_ text: String) async {
        // ElevenLabs first; Apple TTS only on failure or when the user is
        // not Pro. Either way The Sim talks — never silent.
        //
        // ElevenLabsService.speak() awaits playback completion, so the
        // surrounding `await` keeps `isThinking = true` for the full duration
        // of the avatar's voice line. The mic gesture is gated on
        // `!isThinking`, so the user can't record over the avatar.

        // Voice gate — three paths grant real ElevenLabs voice in production:
        //   1. Pro / Pro+ subscriber (unlimited)
        //   2. Free user inside the 2-session lifetime taste-test
        //   3. Tester with the "Force unlock ElevenLabs voice" debug toggle on
        // The #if DEBUG override below ALWAYS allows voice in Xcode dev
        // builds so I can iterate on voice tuning without burning the taste-
        // test counter. TestFlight uses the production branch.
        #if DEBUG
        let useEleven = !avatar.elevenLabsVoiceID.isEmpty  // dev-only — bypasses freemium gate
        #else
        let useEleven = !avatar.elevenLabsVoiceID.isEmpty && (
            StoreManager.shared.isPro ||
            StoreManager.shared.debugForceElevenLabsVoice ||
            StoreManager.shared.simFreeSessionsUsedTotal < StoreManager.freeSimSessionLimit
        )
        #endif

        if useEleven {
            print("[Sim] ElevenLabs speak called for voice=\(avatar.elevenLabsVoiceID)")
            do {
                try await ElevenLabsService.shared.speak(
                    text,
                    voiceID: avatar.elevenLabsVoiceID,
                    settings: avatar.voiceSettings
                )
                print("[Sim] Speak result: success")
            } catch {
                print("[Sim] Speak result: error — \(error.localizedDescription)")
                AppleTTSService.shared.speak(text, reason: "ElevenLabs failed — \(error.localizedDescription)")
            }
        } else {
            let reason = avatar.elevenLabsVoiceID.isEmpty
                ? "avatar has no ElevenLabs voice ID"
                : "user is not Pro"
            print("[Sim] Speak result: skipped — \(reason)")
            AppleTTSService.shared.speak(text, reason: reason)
        }
    }

    // MARK: End

    private func endSession(_ reason: EndReason) {
        guard !sessionEnded else { return }
        sessionEnded = true
        endReason = reason
        timerCancellable?.cancel()
        speech.stop()
        ElevenLabsService.shared.stop()
        AppleTTSService.shared.stop()

        // Session results feed RI Score per Step 9 wiring.
        let questionCount = messages.filter { $0.role == .user && $0.text.contains("?") }.count
        if questionCount >= 3 { RIScoreStore.shared.bumpCuriosity(by: 4) }
        else if questionCount >= 1 { RIScoreStore.shared.bumpCuriosity(by: 2) }

        // Attunement: did the user adapt — proxied here by ending engagement state.
        if meter.score >= 60 { RIScoreStore.shared.bumpAttunement(by: 4) }
        else if meter.score >= 35 { RIScoreStore.shared.bumpAttunement(by: 1) }
        else { RIScoreStore.shared.bumpAttunement(by: -2) }

        showDebrief = true
    }

    enum EndReason { case userEnded, timeUp, disengaged }
}

// MARK: - Tiny UI helpers

private struct InterruptionBanner: View {
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "eye.fill")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(LinearGradient.accent)
                .clipShape(Circle())
            Text(text).font(RWF.cap(12)).foregroundColor(.rwInkText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(SP.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: RR.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RR.md, style: .continuous)
            .stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}

private struct TypingIndicator: View {
    let color: Color
    @State private var phase = 0
    @State private var cancellable: AnyCancellable?
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle().fill(Color.white.opacity(phase == i ? 0.9 : 0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white.opacity(0.10))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        .onAppear {
            cancellable = Timer.publish(every: 0.35, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    phase = (phase + 1) % 3
                }
        }
        .onDisappear {
            cancellable?.cancel()
            cancellable = nil
        }
    }
}

// MARK: - Avatar Waveform
// Five vertical bars under the avatar. Idle: tiny static dots. Active
// (isThinking == true): each bar springs up and down on its own phase, so
// the avatar reads as "speaking". No real audio analysis — purely visual.

struct AvatarWaveform: View {
    let active: Bool
    let color: Color
    @State private var phase = 0
    @State private var cancellable: AnyCancellable?
    private let bars = 5
    // Pseudo-random heights per bar, 0..1. Same seeds → same rhythm each tick.
    private let amplitudes: [[CGFloat]] = [
        [0.30, 0.85, 0.55, 1.00, 0.40],
        [0.70, 0.40, 0.95, 0.55, 0.85],
        [0.90, 0.65, 0.35, 0.80, 0.55],
        [0.45, 1.00, 0.70, 0.30, 0.95],
    ]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<bars, id: \.self) { i in
                Capsule()
                    .fill(active ? color : Color.white.opacity(0.20))
                    .frame(width: 3, height: barHeight(i))
                    .shadow(color: active ? color.opacity(0.5) : .clear,
                            radius: 4, x: 0, y: 0)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.18), value: phase)
        .animation(.easeOut(duration: 0.25), value: active)
        .onAppear {
            cancellable = Timer.publish(every: 0.16, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    phase = (phase + 1) % amplitudes.count
                }
        }
        .onDisappear {
            cancellable?.cancel()
            cancellable = nil
        }
    }

    private func barHeight(_ index: Int) -> CGFloat {
        guard active else { return 4 }
        let amp = amplitudes[phase % amplitudes.count][index % bars]
        return 5 + amp * 14
    }
}
