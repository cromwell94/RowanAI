
// MARK: - Cyrano Tab Button

struct CyranoTabButton: View {
    let title: String; let icon: String; let active: Bool; let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
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
    @State private var cyranoMode: CyranoTab = .reply
    @State private var showPaywall = false
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
    @State private var subtext  = ""
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

    enum CyranoTab { case reply, coach, lab }
    enum ReplySubMode: Hashable { case coach, fillMeIn, screenshot }
    @State private var replySub: ReplySubMode = .coach
    @State private var showProfileCoach = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Mode picker
                RWSegmentedPicker(
                    options: [
                        (value: CyranoTab.reply, label: "Reply",   icon: "bubble.left.and.bubble.right.fill"),
                        (value: CyranoTab.coach, label: "Coach",   icon: "graduationcap.fill"),
                        (value: CyranoTab.lab,   label: "Lab",     icon: "message.fill")
                    ],
                    selected: $cyranoMode
                )
                .padding(.horizontal, SP.lg).padding(.top, 8)

                if cyranoMode == .coach {
                    ConversationCoachView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                } else if cyranoMode == .lab {
                    CommunicationLabView()
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                } else {
            // Reply mode — has 3 sub-tabs: Reply Coach, Fill Me In, Screenshot.
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
                                    .font(.system(size: 13, weight: .medium))
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
                                    .font(.system(size: 13, weight: .medium))
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
                                            Image(systemName: g.icon).font(.system(size: 11, weight: .medium))
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
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(LinearGradient.accent)
                            Text("\(store.repliesRemainingToday()) free \(store.repliesRemainingToday() == 1 ? "reply" : "replies") left today")
                                .font(RWF.cap(12))
                                .foregroundColor(.rwTextSecondary)
                            Spacer()
                            Button { showPaywall = true } label: {
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
                            showPaywall = true
                        }
                    }
                    .disabled(loading || (message.trimmingCharacters(in: .whitespaces).isEmpty && screenshotImage == nil))
                    .opacity((message.isEmpty && screenshotImage == nil) ? 0.5 : 1)

                    HStack(spacing: 4) {
                        Image(systemName: "info.circle").font(.system(size: 11))
                        Text("AI suggestions only — not professional advice").font(.system(size: 11))
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
                                        Text("📸").font(.system(size: 10))
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
                                        .font(.system(size: 11)).foregroundColor(.rwTextMuted)
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

                            if subtext.isEmpty {
                                RWButton("Decode the Subtext", icon: "eye.fill", style: .ghost) {
                                    Task { await decode() }
                                }
                            } else {
                                RWCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label("What They Actually Mean", systemImage: "brain.head.profile")
                                            .font(RWF.head(14)).foregroundColor(.rwTextPrimary)
                                        Text(subtext).font(RWF.body()).foregroundColor(.rwTextSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }

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
            .rwBG()
            .hideKB()
            } // end reply-coach/screenshot subtree
            } // end reply mode
            }
            .rwBG()
            .navigationTitle("Cyrano")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPaywall) { PaywallView(reason: .repliesLimit) }
            .sheet(isPresented: $showProfileCoach) {
                ProfileCoachView()
            }
            .sheet(item: $presentingExercise) { suggestion in
                CyranoExerciseHost(suggestion: suggestion)
            }
            .tutorial(.cyrano, forceShow: $replayTutorial)
            .onChange(of: message) {
                let newVal = message
                // Debounce — analyze after user stops typing for 1.5 seconds
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

    // MARK: - Screenshot preview + loader

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
                        .font(.system(size: 11, weight: .bold))
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
        loading = true; error = ""; subtext = ""; visionFallback = false
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

    func decode() async {
        loading = true
        do { subtext = try await Claude.shared.subtext(message: message, context: context) }
        catch let e { error = e.localizedDescription }
        loading = false
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
                    Image(systemName: r.tone.icon).font(.system(size: 11, weight: .bold))
                    Text(r.tone.rawValue.uppercased()).font(RWF.micro()).tracking(1.5)
                }
                .foregroundColor(r.tone.color).padding(.horizontal, 9).padding(.vertical, 4)
                .background(r.tone.color.opacity(0.12)).clipShape(Capsule())
                Spacer()
                Button(action: copy) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 12, weight: .semibold))
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
                Image(systemName: "lightbulb.fill").font(.system(size: 10)).foregroundColor(.rwGold)
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
            Image(systemName: "brain.head.profile").font(.system(size: 16))
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
                    .font(.system(size: 14, weight: .semibold))
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
                        .font(.system(size: 12, weight: .semibold))
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

