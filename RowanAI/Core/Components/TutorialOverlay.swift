import SwiftUI

// MARK: - Tutorial Overlay
// A premium step-through overlay with animated transitions, dot indicator,
// and a "Don't show tutorials again" toggle on the final step. Used both as
// a first-launch introduction AND as a replay surface when the user taps
// the "?" affordance on any screen.

struct TutorialOverlay: View {
    let tutorial: Tutorial
    let onFinish: () -> Void

    @State private var step: Int = 0
    @State private var disableAll = false
    @State private var visible = false

    private var isLastStep: Bool { step == tutorial.steps.count - 1 }

    var body: some View {
        ZStack {
            Color.rwBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer().frame(height: 24)
                stepBody
                Spacer()
                if isLastStep { dontShowToggle }
                bottomBar
            }
            .padding(.horizontal, SP.lg)
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 12)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { visible = true }
        }
    }

    // MARK: Top — eyebrow + close + dot indicator

    private var topBar: some View {
        VStack(spacing: 18) {
            HStack {
                Text(tutorial.estimatedTime.uppercased())
                    .font(RWF.micro())
                    .foregroundColor(.rwTextMuted)
                    .tracking(1.4)
                Spacer()
                Button(action: skip) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.rwTextSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color.rwSurface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.rwBorder, lineWidth: 1))
                }
                .buttonStyle(SBS())
            }
            .padding(.top, 16)

            HStack(spacing: 6) {
                ForEach(0..<tutorial.steps.count, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? AnyShapeStyle(LinearGradient.accent)
                                        : AnyShapeStyle(Color.rwBorder))
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                        .animation(.easeInOut(duration: 0.25), value: step)
                }
            }
        }
    }

    // MARK: Body — icon + title + step content

    private var stepBody: some View {
        let current = tutorial.steps[step]
        return VStack(alignment: .leading, spacing: 18) {
            Text(tutorial.title.uppercased())
                .font(RWF.micro())
                .foregroundStyle(LinearGradient.accent)
                .tracking(1.6)

            iconBlock(for: current)

            Text(current.headline)
                .font(RWF.display(28))
                .foregroundColor(.rwTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(current.body)
                .font(RWF.body(16))
                .foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let tip = current.tip, !tip.isEmpty {
                tipCard(tip)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .id(step) // force re-build so the transition fires per step
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal:   .opacity.combined(with: .move(edge: .leading))
        ))
    }

    private func iconBlock(for s: TutorialStep) -> some View {
        // Treat single-character / short emoji entries as text; treat
        // longer SF Symbol identifiers via Image(systemName:).
        let isEmoji = s.icon.count <= 2 && !s.icon.contains(".")
        return ZStack {
            Circle()
                .fill(LinearGradient.accentSoft)
                .frame(width: 88, height: 88)
            Circle()
                .fill(Color.rwAccent.opacity(0.10))
                .frame(width: 60, height: 60)
            if isEmoji {
                Text(s.icon).font(.system(size: 36, design: .rounded))
            } else {
                Image(systemName: s.icon)
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .foregroundStyle(LinearGradient.accent)
            }
        }
    }

    private func tipCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(LinearGradient.accent)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 4) {
                Text("TIP")
                    .font(RWF.micro())
                    .foregroundStyle(LinearGradient.accent)
                    .tracking(1.6)
                Text(text)
                    .font(RWF.body(14))
                    .foregroundColor(.rwTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SP.md)
        .background(LinearGradient.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwAccent.opacity(0.25), lineWidth: 1))
    }

    // MARK: Footer — buttons + don't-show toggle

    private var dontShowToggle: some View {
        Button {
            disableAll.toggle()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: disableAll ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(disableAll ? .rwAccent : .rwTextMuted)
                Text("Don't show tutorials again")
                    .font(RWF.cap(13))
                    .foregroundColor(.rwTextSecondary)
                Spacer()
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(SBS())
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            RWButton(isLastStep ? "Got it" : "Next", icon: isLastStep ? "checkmark" : "arrow.right") {
                advance()
            }
            if !isLastStep {
                Button("Skip") { skip() }
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
            }
        }
        .padding(.bottom, 44)
    }

    // MARK: - Actions

    private func advance() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if isLastStep {
            finish()
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                step += 1
            }
        }
    }

    private func skip() {
        finish()
    }

    private func finish() {
        TutorialManager.shared.markSeen(tutorial.id)
        if disableAll {
            TutorialManager.shared.tutorialsEnabled = false
        }
        onFinish()
    }
}

// MARK: - View Modifier
// Auto-presents the overlay on first appearance if the tutorial hasn't been
// seen and the global toggle is on. Use:
//     SomeView().tutorial(.home)
// On replay-by-tap (the "?" button), call TutorialManager.shared.replay(id)
// before triggering the same modifier — the controlled `forceShow` binding
// overrides the should-show logic.

extension View {
    func tutorial(_ id: TutorialID,
                  forceShow: Binding<Bool>? = nil) -> some View {
        self.modifier(TutorialModifier(id: id, forceShow: forceShow))
    }
}

private struct TutorialModifier: ViewModifier {
    let id: TutorialID
    let forceShow: Binding<Bool>?

    @State private var presented = false
    @State private var manager = TutorialManager.shared

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard forceShow == nil else { return }
                if manager.shouldShow(id) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        presented = true
                    }
                }
            }
            .onChange(of: forceShow?.wrappedValue ?? false) { _, newValue in
                if newValue { presented = true }
            }
            .fullScreenCover(isPresented: $presented) {
                TutorialOverlay(
                    tutorial: TutorialContent.tutorial(for: id),
                    onFinish: {
                        presented = false
                        forceShow?.wrappedValue = false
                    }
                )
            }
    }
}

// MARK: - Replay Button
// The "?" affordance — drop into any screen's toolbar / overlay. Tapping it
// re-arms the tutorial regardless of seen state. Stays visible even when the
// global tutorials toggle is off so the user can still ask for a refresher.

struct TutorialReplayButton: View {
    let id: TutorialID
    @Binding var forceShow: Bool

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            TutorialManager.shared.replay(id)
            forceShow = true
        } label: {
            Image(systemName: "questionmark")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(LinearGradient.accent)
                .frame(width: 32, height: 32)
                .background(Color.rwSurface)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.rwAccent.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(SBS())
    }
}
