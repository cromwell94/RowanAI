
// MARK: - Cyrano Tab Button

struct CyranoTabButton: View {
    let title: String; let icon: String; let active: Bool; let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold, design: .rounded))
                Text(title).font(RWF.cap(12))
            }
            .foregroundColor(active ? .white : .rwTextSecondary)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(active ? Color(hex: "0D0D0D") : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: RR.md))
        }
        .buttonStyle(SBS())
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: active)
    }
}

import SwiftUI
import Combine
import PhotosUI

struct CyranoView: View {
    // v1.0 — Cyrano is now a 5-mode communication toolkit.
    // Reply / Opener / Translate / Decode / Pulse.
    // - Reply preserves the existing 3 sub-modes (Reply Coach / Fill Me In / Screenshot).
    // - Opener ships end-to-end this turn (new vision-based feature).
    // - Translate / Decode / Pulse render "Coming soon" placeholders for v1.0
    //   first ship; full implementations land in the next iteration.
    // - Coach + Lab moved out of Cyrano into arc-nav destinations (see ArcNavigation.swift).
    @AppStorage("cyranoMode") private var cyranoMode: String = "reply"

    @State private var showPaywall = false
    @State private var paywallReason: PaywallView.PaywallReason = .repliesLimit
    @State private var store = StoreManager.shared
    @State private var intel: ConversationIntel? = nil
    @State private var intelLoading = false
    @State private var intelDismissed = false
    @State private var intelTask: Task<Void, Never>? = nil
    @State private var message  = ""
    @State private var context  = ""
    @State private var showCtx  = false
    @State private var goal: RWUser.DatingGoal = .relationship
    @State private var replies: [CyranoSuggestion] = []
    @State private var loading  = false
    @State private var error    = ""
    @State private var copied: UUID? = nil
    @State private var showCrisis = false
    @State private var showHarmfulWarning = false
    @FocusState private var msgF: Bool
    @FocusState private var ctxF: Bool

    // Screenshot upload state — Build 1, Cyrano vision support.
    @State private var screenshotPick: PhotosPickerItem? = nil
    @State private var screenshotImage: UIImage? = nil
    @State private var lastSendIncludedScreenshot = false
    @State private var visionFallback = false

    // Contextual exercise suggestion — appended by Cyrano when a pattern is
    // detected. Rendered as a tappable card below the replies.
    @State private var exerciseSuggestion: CyranoExerciseSuggestion? = nil
    @State private var presentingExercise: CyranoExerciseSuggestion? = nil
    @State private var replayTutorial = false

    enum ReplySubMode: Hashable { case coach, fillMeIn, screenshot }
    @State private var replySub: ReplySubMode = .coach
    @State private var showProfileCoach = false

    // Opener mode state (v1.0)
    @State private var openerPick: PhotosPickerItem? = nil
    @State private var openerImage: UIImage? = nil
    @State private var openers: [Claude.CyranoOpenerSuggestion] = []
    @State private var openerLoading = false
    @State private var openerError = ""
    @State private var openerCopied: UUID? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 5-mode pill selector — horizontally scrollable so future
                // additions don't have to fight a fixed segmented control.
                modeSelector
                    .padding(.horizontal, SP.lg).padding(.top, 8)

                Group {
                    switch cyranoMode {
                    case "opener":
                        openerModeContent
                    case "translate":
                        comingSoonView(
                            mode: "Translate",
                            icon: "arrow.triangle.2.circlepath.icloud",
                            headline: "About to send something you'll regret?",
                            sub: "Cyrano will rewrite your message so they can actually hear you. Coming soon.")
                    case "decode":
                        comingSoonView(
                            mode: "Decode",
                            icon: "brain.head.profile",
                            headline: "Spiraling about a text?",
                            sub: "See what your anxious/avoidant brain heard vs what they actually meant. Coming soon.")
                    case "pulse":
                        comingSoonView(
                            mode: "Pulse",
                            icon: "waveform.path.ecg",
                            headline: "Need a quick read on the situation?",
                            sub: "Tell Cyrano what's happening. Get instant clarity in 10 seconds. Coming soon.")
                    default:
                        replyModeContent
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: cyranoMode)
            }
            .rwBG()
            .navigationTitle("Cyrano")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPaywall) { PaywallView(reason: paywallReason) }
            .sheet(isPresented: $showProfileCoach) {
                ProfileCoachView()
            }
            .sheet(item: $presentingExercise) { suggestion in
                CyranoExerciseHost(suggestion: suggestion)
            }
            .tutorial(.cyrano, forceShow: $replayTutorial)
            .onChange(of: message) {
                let newVal = message
                intelTask?.cancel()
                intelDismissed = false
                intel = nil
                guard newVal.count > 30 else { return }
                intelTask = Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    guard !Task.isCancelled else { return }
                    let result = await Claude.shared.analyzeConversation(
                        theirMessage: newVal,
                        context: context,
                        gender: AuthService.shared.currentUser?.gender ?? .preferNotToSay
                    )
                    await MainActor.run {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            intel = result
                        }
                    }
                }
            }
        }
    }

    // MARK: - Mode Selector (horizontal pills)

    private var modeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                modePill("reply",     label: "Reply",     icon: "bubble.left.fill")
                modePill("opener",    label: "Opener",    icon: "person.crop.rectangle.stack")
                modePill("translate", label: "Translate", icon: "arrow.triangle.2.circlepath.icloud")
                modePill("decode",    label: "Decode",    icon: "brain.head.profile")
                modePill("pulse",     label: "Pulse",     icon: "waveform.path.ecg")
            }
        }
    }

    private func modePill(_ value: String, label: String, icon: String) -> some View {
        let active = cyranoMode == value
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                cyranoMode = value
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold, design: .rounded))
                Text(label).font(RWF.cap(13))
            }
            .foregroundColor(active ? .white : .rwTextMuted)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(active ? AnyShapeStyle(Color.rwAccent) : AnyShapeStyle(Color.clear))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(active ? Color.clear : Color.rwBorder, lineWidth: 1))
        }
        .buttonStyle(SBS())
    }

    // MARK: - Reply Mode (preserved — sub-tabs + existing flow, minus Decode-Subtext button)

    @ViewBuilder
    private var replyModeContent: some View {
        // Reply mode — preserves the existing 3 sub-tabs.
        RWSegmentedPicker(
            options: [
                (value: ReplySubMode.coach,      label: "Reply Coach", icon: "bubble.left.fill"),
                (value: ReplySubMode.fillMeIn,   label: "Fill Me In",  icon: "list.bullet.rectangle.fill"),
                (value: ReplySubMode.screenshot, label: "Screenshot",  icon: "photo.fill")
            ],
            selected: $replySub
        )
        .padding(.horizontal, SP.lg).padding(.top, 8).padding(.bottom, 4)

        if replySub == .fillMeIn {
            FillMeInView()
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {

                    CrisisBanner(show: $showCrisis)

                    if showHarmfulWarning {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundColor(Color(hex: "F59E0B"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("We can't help with that").font(RWF.head(14)).foregroundColor(.rwTextPrimary)
                                Text("Rowan is built for genuine connection — not to help harm or manipulate others.")
                                    .font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Button { withAnimation { showHarmfulWarning = false } } label: {
                                Image(systemName: "xmark").foregroundColor(.rwTextMuted)
                            }
                        }
                        .padding(SP.md).background(Color(hex: "F59E0B").opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color(hex: "F59E0B").opacity(0.2), lineWidth: 1))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if !AISettings.shared.isEnabled {
                        AIOffBanner(feature: "Cyrano", msg: "Turn on AI to get reply suggestions.")
                    }

                    // Hero — sets context for what this surface does.
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(replySub == .screenshot ? "SCREENSHOT" : "REPLY COACH")
                                .font(RWF.micro())
                                .foregroundStyle(LinearGradient.accent)
                                .tracking(1.6)
                            Text(replySub == .screenshot ? "Drop in a screenshot." : "Paste their message.")
                                .font(RWF.title(24))
                                .foregroundColor(.rwTextPrimary)
                            Text(replySub == .screenshot
                                 ? "Cyrano reads the conversation and writes replies in different tones."
                                 : "Cyrano writes five replies in different tones — pick the one that sounds like you.")
                                .font(RWF.body(15))
                                .foregroundColor(.rwTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        TutorialReplayButton(id: .cyrano, forceShow: $replayTutorial)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                    // Profile Coach entry — only on the Reply Coach sub-mode
                    // since it's the landing surface for Cyrano.
                    if replySub == .coach {
                        ProfileCoachEntryCard {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showProfileCoach = true
                        }
                    }

                    // Screenshot preview — appears above the input when an
                    // image is attached. Tap the X to remove.
                    if let img = screenshotImage {
                        screenshotPreviewCard(img)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Message input
                    TBox(label: "Their Message", icon: "bubble.right.fill",
                         ph: screenshotImage == nil
                            ? "Paste or type what they said..."
                            : "Optional note for Cyrano about the screenshot…",
                         text: $message,
                         min: 90, max: 160, focused: $msgF)

                    // Action row — screenshot picker + context toggle.
                    HStack(spacing: 10) {
                        PhotosPicker(selection: $screenshotPick,
                                     matching: .images,
                                     photoLibrary: .shared()) {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                Text(screenshotImage == nil ? "Add screenshot" : "Replace screenshot")
                                    .font(RWF.cap(12))
                            }
                            .foregroundColor(.rwAccent)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.rwAccent.opacity(0.10))
                            .clipShape(Capsule())
                        }
                        .onChange(of: screenshotPick) { _, item in
                            Task { await loadScreenshot(item) }
                        }

                        Button { withAnimation { showCtx.toggle() } } label: {
                            HStack(spacing: 6) {
                                Image(systemName: showCtx ? "minus.circle" : "plus.circle")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                Text(showCtx ? "Remove context" : "Add context")
                                    .font(RWF.cap(12))
                            }
                            .foregroundColor(.rwTextSecondary)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.rwSurface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.rwBorder, lineWidth: 1))
                        }
                        .buttonStyle(SBS())
                        Spacer()
                    }

                    if showCtx {
                        TBox(label: "Prior Context", icon: "clock.fill",
                             ph: "Paste the conversation thread...", text: $context,
                             min: 80, max: 120, focused: $ctxF)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Passive intel banner
                    if let intel = intel, !intelDismissed {
                        CyranoIntelBanner(intel: intel) {
                            withAnimation { intelDismissed = true }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Goal chips — explicitly labeled so the user knows why
                    // we're asking. Premium pill chips with shadow on selected.
                    VStack(alignment: .leading, spacing: 8) {
                        RWSectionLabel("DATING GOAL")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(RWUser.DatingGoal.allCases, id: \.rawValue) { g in
                                    Button {
                                        goal = g
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: g.icon).font(.system(size: 11, weight: .medium, design: .rounded))
                                            Text(g.rawValue).font(RWF.cap(12))
                                        }
                                        .foregroundColor(goal == g ? .white : .rwTextSecondary)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(goal == g ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.rwCard))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(goal == g ? Color.clear : Color.rwBorder, lineWidth: 1))
                                        .shadow(color: goal == g ? Color.rwAccent.opacity(0.25) : .clear,
                                                radius: 8, x: 0, y: 3)
                                    }
                                    .buttonStyle(SBS())
                                }
                            }
                        }
                    }

                    // Free tier counter — quiet utility row.
                    if !store.isPro {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkle")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(LinearGradient.accent)
                                .symbolEffect(.bounce, options: .nonRepeating, value: store.repliesRemainingToday())
                            Text("\(store.repliesRemainingToday()) free \(store.repliesRemainingToday() == 1 ? "reply" : "replies") left today")
                                .font(RWF.cap(12))
                                .foregroundColor(.rwTextSecondary)
                                .contentTransition(.numericText())
                            Spacer()
                            Button {
                                paywallReason = .repliesLimit
                                showPaywall = true
                            } label: {
                                Text("Go Pro")
                                    .font(RWF.cap(12))
                                    .foregroundStyle(LinearGradient.accent)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color.rwSurface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.rwBorder, lineWidth: 1))
                    }

                    RWButton(loading ? "Thinking..." : "Generate Replies", icon: loading ? nil : "sparkles") {
                        msgF = false; ctxF = false
                        if store.canUseReplies() {
                            Task { await generate() }
                        } else {
                            paywallReason = .repliesLimit
                            showPaywall = true
                        }
                    }
                    .disabled(loading || (message.trimmingCharacters(in: .whitespaces).isEmpty && screenshotImage == nil))
                    .opacity((message.isEmpty && screenshotImage == nil) ? 0.5 : 1)

                    HStack(spacing: 4) {
                        Image(systemName: "info.circle").font(.system(size: 11, design: .rounded))
                        Text("AI suggestions only — not professional advice").font(.system(size: 11, design: .rounded))
                    }
                    .foregroundColor(.rwTextMuted)

                    if !error.isEmpty {
                        Text(error).font(RWF.body(13)).foregroundColor(.rwDanger)
                            .padding(SP.md).background(Color.rwDanger.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: RR.md))
                    }

                    if loading { Dots(msg: "Reading between the lines...") }

                    if !replies.isEmpty {
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                RWSectionLabel("YOUR REPLIES")
                                if lastSendIncludedScreenshot {
                                    HStack(spacing: 4) {
                                        Text("📸").font(.system(size: 10, design: .rounded))
                                        Text("with screenshot").font(RWF.cap(11))
                                    }
                                    .foregroundColor(.rwAccent)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.rwAccent.opacity(0.10))
                                    .clipShape(Capsule())
                                }
                            }
                            if visionFallback {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.system(size: 11, design: .rounded)).foregroundColor(.rwTextMuted)
                                    Text("Screenshot couldn't be processed — coaching based on your description.")
                                        .font(RWF.cap(11)).foregroundColor(.rwTextMuted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            ForEach(Array(replies.enumerated()), id: \.element.id) { index, r in
                                ReplyCard(r: r, copied: copied == r.id) {
                                    UIPasteboard.general.string = r.text
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    copied = r.id
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = nil }
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }

                            // "Decode the Subtext" inline button removed in v1.0 —
                            // the new top-level Decode mode replaces this with a
                            // richer structured output (what-you-heard vs
                            // what-they-meant + suggested response). Ships in the
                            // next iteration; Decode pill currently shows "Coming soon".

                            // Pattern-based exercise suggestion (Cyrano notices something).
                            if let suggestion = exerciseSuggestion {
                                CyranoExerciseSuggestionCard(
                                    suggestion: suggestion,
                                    onOpen: {
                                        presentingExercise = suggestion
                                    },
                                    onDismiss: {
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            exerciseSuggestion = nil
                                        }
                                    }
                                )
                            }
                        }
                    }

                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, SP.lg).padding(.top, 20)
            }
            .hideKB()
        } // end fillMeIn / coach-or-screenshot branch
    }

    // MARK: - Opener Mode (v1.0 — new)

    @ViewBuilder
    private var openerModeContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                if !AISettings.shared.isEnabled {
                    AIOffBanner(feature: "Opener", msg: "Turn on AI to get opening message suggestions.")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("OPENER")
                        .font(RWF.micro())
                        .foregroundStyle(LinearGradient.accent)
                        .tracking(1.6)
                    Text("Got a match? Let's open strong.")
                        .font(RWF.title(24))
                        .foregroundColor(.rwTextPrimary)
                    Text("Screenshot their profile and Cyrano will suggest three openers tailored to them.")
                        .font(RWF.body(15))
                        .foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)

                if let img = openerImage {
                    openerPreviewCard(img)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if openerImage == nil && openers.isEmpty && !openerLoading {
                    VStack(spacing: 14) {
                        Image(systemName: "person.crop.rectangle.stack")
                            .font(.system(size: 48, weight: .medium, design: .rounded))
                            .foregroundStyle(LinearGradient.accent)
                        Text("Upload a profile screenshot")
                            .font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                        Text("Cyrano reads photos, prompts, and bio — then writes Curious, Witty, and Bold openers.")
                            .font(RWF.cap(12))
                            .foregroundColor(.rwTextSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, SP.lg)
                    }
                    .padding(.vertical, SP.xl)
                    .frame(maxWidth: .infinity)
                }

                PhotosPicker(selection: $openerPick,
                             matching: .images,
                             photoLibrary: .shared()) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text(openerImage == nil ? "Upload profile screenshot" : "Replace screenshot")
                            .font(RWF.med(14))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient.accent)
                    .clipShape(Capsule())
                    .shadow(color: Color.rwAccent.opacity(0.25), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(SBS())
                .onChange(of: openerPick) { _, item in
                    Task { await loadOpenerImage(item) }
                }

                if !store.isPro {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(LinearGradient.accent)
                        Text("\(store.openersRemainingToday()) free \(store.openersRemainingToday() == 1 ? "opener" : "openers") left today")
                            .font(RWF.cap(12))
                            .foregroundColor(.rwTextSecondary)
                            .contentTransition(.numericText())
                        Spacer()
                        Button {
                            paywallReason = .openersLimit
                            showPaywall = true
                        } label: {
                            Text("Go Pro")
                                .font(RWF.cap(12))
                                .foregroundStyle(LinearGradient.accent)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.rwSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.rwBorder, lineWidth: 1))
                }

                if openerImage != nil {
                    RWButton(openerLoading ? "Reading profile..." : "Generate Openers",
                             icon: openerLoading ? nil : "sparkles") {
                        if store.canUseOpener() {
                            Task { await generateOpeners() }
                        } else {
                            paywallReason = .openersLimit
                            showPaywall = true
                        }
                    }
                    .disabled(openerLoading)
                }

                if !openerError.isEmpty {
                    Text(openerError).font(RWF.body(13)).foregroundColor(.rwDanger)
                        .padding(SP.md).background(Color.rwDanger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: RR.md))
                }

                if openerLoading { Dots(msg: "Reading their profile...") }

                if !openers.isEmpty {
                    VStack(spacing: 12) {
                        RWSectionLabel("YOUR OPENERS")
                        ForEach(openers) { o in
                            OpenerCard(opener: o, copied: openerCopied == o.id) {
                                UIPasteboard.general.string = o.text
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                openerCopied = o.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { openerCopied = nil }
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                    }
                }

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg).padding(.top, 20)
        }
        .hideKB()
    }

    private func openerPreviewCard(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                    .overlay(RoundedRectangle(cornerRadius: RR.lg)
                        .stroke(Color.rwAccent.opacity(0.3), lineWidth: 1))
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        openerImage = nil
                        openerPick = nil
                        openers = []
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .padding(8)
            }
            Text("Cyrano will read this profile")
                .font(RWF.cap(11))
                .foregroundColor(.rwTextMuted)
        }
    }

    @MainActor
    private func loadOpenerImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                openerImage = image
                openers = []
            }
        }
    }

    // MARK: - Coming Soon Placeholder (Translate / Decode / Pulse)

    private func comingSoonView(mode: String, icon: String, headline: String, sub: String) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.xl) {
                VStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 48, weight: .medium, design: .rounded))
                        .foregroundStyle(LinearGradient.accent)
                        .padding(.top, 60)
                    Text(mode.uppercased())
                        .font(RWF.micro())
                        .foregroundStyle(LinearGradient.accent)
                        .tracking(1.6)
                    Text(headline)
                        .font(RWF.title(22))
                        .foregroundColor(.rwTextPrimary)
                        .multilineTextAlignment(.center)
                    Text(sub)
                        .font(RWF.body(14))
                        .foregroundColor(.rwTextSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, SP.xl)
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        Text("Coming soon").font(RWF.cap(12))
                    }
                    .foregroundColor(.rwAccent)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.rwAccent.opacity(0.1))
                    .clipShape(Capsule())
                    .padding(.top, 4)
                }
                Spacer()
            }
            .padding(SP.lg)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Screenshot preview + loader (Reply mode)

    private func screenshotPreviewCard(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 80)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                    .overlay(RoundedRectangle(cornerRadius: RR.lg)
                        .stroke(Color.rwAccent.opacity(0.3), lineWidth: 1))
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        screenshotImage = nil
                        screenshotPick = nil
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .padding(8)
            }
            Text("Cyrano will read this conversation")
                .font(RWF.cap(11))
                .foregroundColor(.rwTextMuted)
        }
    }

    @MainActor
    private func loadScreenshot(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                screenshotImage = image
            }
        }
    }

    func generate() async {
        loading = true; error = ""; visionFallback = false
        let attachedImage = screenshotImage
        let didIncludeImage = (attachedImage != nil)
        do {
            let result = try await Claude.shared.replies(
                message: message,
                context: context,
                goal: goal,
                image: attachedImage)
            replies = result.replies
            exerciseSuggestion = result.exercise
            lastSendIncludedScreenshot = didIncludeImage
            // Clear the screenshot only after a successful generation so a
            // failed call leaves the user's attachment intact for retry.
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    screenshotImage = nil
                    screenshotPick = nil
                }
            }
            StoreManager.shared.trackReplyUsed()
            StreakManager.shared.addPoints(5, reason: "reply")
        }
        catch let e {
            if e.localizedDescription == "crisis" {
                withAnimation { showCrisis = true }
            } else if e.localizedDescription == "harmful" {
                withAnimation { showHarmfulWarning = true }
            } else if didIncludeImage {
                // Vision call failed — try once more without the image so the
                // user still gets coaching from their description.
                visionFallback = true
                do {
                    let result = try await Claude.shared.replies(
                        message: message.isEmpty
                            ? "(The user attached a screenshot but the upload failed. Coach generally based on whatever context you have.)"
                            : message,
                        context: context,
                        goal: goal,
                        image: nil)
                    replies = result.replies
                    exerciseSuggestion = result.exercise
                    lastSendIncludedScreenshot = false
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.2)) {
                            screenshotImage = nil
                            screenshotPick = nil
                        }
                    }
                } catch {
                    self.error = e.localizedDescription
                }
            } else {
                self.error = e.localizedDescription
            }
        }
        loading = false
    }

    // Opener generate — calls Claude.shared.openers(image:) which routes
    // through the cyrano edge function with mode="opener" so it lands in
    // the cyrano_opener rate-limit bucket on the server.
    func generateOpeners() async {
        guard let img = openerImage else { return }
        openerLoading = true; openerError = ""
        do {
            let result = try await Claude.shared.openers(image: img)
            openers = result
            StoreManager.shared.trackOpenerUsed()
            StreakManager.shared.addPoints(5, reason: "opener")
        } catch {
            openerError = "Couldn't read that profile. Try a clearer screenshot."
        }
        openerLoading = false
    }

    // (decode() removed in v1.0 — replaced by the standalone Decode mode,
    //  which ships in the next iteration.)
}

// MARK: - Opener Card

struct OpenerCard: View {
    let opener: Claude.CyranoOpenerSuggestion
    let copied: Bool
    let copy: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: opener.style.icon).font(.system(size: 11, weight: .bold, design: .rounded))
                    Text(opener.style.rawValue.uppercased()).font(RWF.micro()).tracking(1.5)
                }
                .foregroundColor(opener.style.color).padding(.horizontal, 9).padding(.vertical, 4)
                .background(opener.style.color.opacity(0.12)).clipShape(Capsule())
                Spacer()
                Button(action: copy) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 12, weight: .semibold, design: .rounded))
                        Text(copied ? "Copied!" : "Copy").font(RWF.cap(12))
                    }
                    .foregroundColor(copied ? .white : .rwTextSecondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(copied ? Color.rwSuccess : Color.rwCard)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(copied ? Color.clear : Color.rwBorder, lineWidth: 1))
                }
                .buttonStyle(SBS())
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: copied)
            }

            Text(opener.text).font(RWF.body()).foregroundColor(.rwTextPrimary).fixedSize(horizontal: false, vertical: true)

            RWLine()

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lightbulb.fill").font(.system(size: 10, design: .rounded)).foregroundColor(.rwGold)
                Text(opener.reasoning).font(RWF.body(12)).foregroundColor(.rwTextMuted).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SP.lg).background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(copied ? opener.style.color.opacity(0.3) : Color.rwBorder, lineWidth: 1))
        .animation(.spring(response: 0.3), value: copied)
    }
}

// MARK: - Text Box

struct TBox: View {
    let label: String; let icon: String; let ph: String
    @Binding var text: String
    var min: CGFloat = 90; var max: CGFloat = 160
    var focused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon).font(RWF.cap()).foregroundColor(.rwTextMuted).tracking(0.5)
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(ph).font(RWF.body()).foregroundColor(.rwTextMuted)
                        .padding(.horizontal, 4).padding(.vertical, 12).allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(RWF.body()).foregroundColor(.rwTextPrimary)
                    .frame(minHeight: min, maxHeight: max)
                    .scrollContentBackground(.hidden).focused(focused)
            }
            .padding(SP.md).background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg)
                .stroke(focused.wrappedValue ? Color.rwAccent.opacity(0.4) : Color.rwBorder, lineWidth: 1))
        }
    }
}

// MARK: - Reply Card

struct ReplyCard: View {
    let r: CyranoSuggestion; let copied: Bool; let copy: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: r.tone.icon).font(.system(size: 11, weight: .bold, design: .rounded))
                    Text(r.tone.rawValue.uppercased()).font(RWF.micro()).tracking(1.5)
                }
                .foregroundColor(r.tone.color).padding(.horizontal, 9).padding(.vertical, 4)
                .background(r.tone.color.opacity(0.12)).clipShape(Capsule())
                Spacer()
                Button(action: copy) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 12, weight: .semibold, design: .rounded))
                        Text(copied ? "Copied!" : "Copy").font(RWF.cap(12))
                    }
                    .foregroundColor(copied ? .white : .rwTextSecondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(copied ? Color.rwSuccess : Color.rwCard)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(copied ? Color.clear : Color.rwBorder, lineWidth: 1))
                }
                .buttonStyle(SBS())
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: copied)
            }

            Text(r.text).font(RWF.body()).foregroundColor(.rwTextPrimary).fixedSize(horizontal: false, vertical: true)

            RWLine()

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lightbulb.fill").font(.system(size: 10, design: .rounded)).foregroundColor(.rwGold)
                Text(r.reasoning).font(RWF.body(12)).foregroundColor(.rwTextMuted).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SP.lg).background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(copied ? r.tone.color.opacity(0.3) : Color.rwBorder, lineWidth: 1))
        .animation(.spring(response: 0.3), value: copied)
    }
}

// MARK: - Loading Dots

struct Dots: View {
    let msg: String
    @State private var d = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Color.rwAccent).frame(width: 8, height: 8)
                        .scaleEffect(d == i ? 1.4 : 0.8)
                        .animation(.spring(response: 0.3).delay(Double(i) * 0.1), value: d)
                }
            }
            Text(msg).font(RWF.body()).foregroundColor(.rwTextSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, SP.xl)
        .onReceive(timer) { _ in d = (d + 1) % 3 }
    }
}

// MARK: - AI Off Banner

struct AIOffBanner: View {
    let feature: String; let msg: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "brain.head.profile").font(.system(size: 16, design: .rounded))
                .foregroundColor(.rwTextMuted).frame(width: 40, height: 40)
                .background(Color.rwCard).clipShape(RoundedRectangle(cornerRadius: RR.md))
            VStack(alignment: .leading, spacing: 3) {
                Text("AI is off").font(RWF.head(14)).foregroundColor(.rwTextPrimary)
                Text(msg).font(RWF.body(13)).foregroundColor(.rwTextSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button { AISettings.shared.isEnabled = true } label: {
                Text("Turn On").font(RWF.cap()).foregroundColor(.rwAccent)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.rwAccent.opacity(0.1)).clipShape(Capsule())
            }
            .buttonStyle(SBS())
        }
        .padding(SP.md).background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
    }
}

// MARK: - Cyrano Intel Banner

struct CyranoIntelBanner: View {
    let intel: ConversationIntel
    let onDismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: intel.type.icon)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(intel.type.color)
                    .frame(width: 36, height: 36)
                    .background(intel.type.color.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Cyrano noticed")
                            .font(RWF.micro())
                            .foregroundColor(.rwTextMuted)
                            .tracking(1)
                        if intel.urgency == .high {
                            Circle()
                                .fill(intel.type.color)
                                .frame(width: 6, height: 6)
                        }
                    }
                    Text(intel.headline)
                        .font(RWF.head(14))
                        .foregroundColor(.rwTextPrimary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.rwTextMuted)
                        .frame(width: 28, height: 28)
                        .background(Color.rwSurface)
                        .clipShape(Circle())
                }
            }

            Text(intel.detail)
                .font(RWF.body(13))
                .foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SP.md)
        .background(
            RoundedRectangle(cornerRadius: RR.xl)
                .fill(intel.type.color.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RR.xl)
                .stroke(intel.type.color.opacity(0.2), lineWidth: 1.5)
        )
        .shadow(color: intel.type.color.opacity(0.1), radius: 8, x: 0, y: 2)
        .scaleEffect(appeared ? 1 : 0.95)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appeared = true
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

