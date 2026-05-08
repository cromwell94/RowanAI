import SwiftUI

struct ProfilePromptTab: View {
    @State private var store = ProfileCoachStore.shared
    @State private var expandedPrompt: String? = nil
    @State private var customPromptText = ""
    @State private var loading: String? = nil
    @State private var error: String = ""
    @State private var showPaywall = false
    @State private var storeManager = StoreManager.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SP.lg) {

                hero
                if !storeManager.isPro { quotaBar }
                appPicker

                if !error.isEmpty {
                    Text(error).font(RWF.body(13)).foregroundColor(.rwDanger)
                        .padding(SP.md).background(Color.rwDanger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: RR.md))
                }

                promptList

                Spacer().frame(height: 100)
            }
            .padding(.horizontal, SP.lg)
            .padding(.top, 12)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .profilePromptLimit)
        }
        .hideKB()
    }

    // MARK: pieces

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PROMPT COACH").font(RWF.micro())
                .foregroundStyle(LinearGradient.accent)
                .tracking(1.6)
            Text("Pick an app, then a prompt.")
                .font(RWF.title(22))
                .foregroundColor(.rwTextPrimary)
            Text("Cyrano writes 3 versions across different tones. Steal what works.")
                .font(RWF.body(14))
                .foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var quotaBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LinearGradient.accent)
            Text("\(storeManager.profilePromptsRemainingToday()) free \(storeManager.profilePromptsRemainingToday() == 1 ? "generation" : "generations") left today")
                .font(RWF.cap(12))
                .foregroundColor(.rwTextSecondary)
            Spacer()
            Button { showPaywall = true } label: {
                Text("Go Pro").font(RWF.cap(12))
                    .foregroundStyle(LinearGradient.accent)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.rwSurface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.rwBorder, lineWidth: 1))
    }

    private var appPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            RWSectionLabel("APP")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DatingApp.allCases) { app in
                        appPill(app)
                    }
                }
            }
        }
    }

    private func appPill(_ app: DatingApp) -> some View {
        let on = store.selectedApp == app
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                store.selectedApp = app
                expandedPrompt = nil
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: app.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(app.rawValue).font(RWF.cap(13))
            }
            .foregroundColor(on ? .white : .rwTextPrimary)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(on ? AnyShapeStyle(app.tint) : AnyShapeStyle(Color.rwCard))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(on ? Color.clear : Color.rwBorder, lineWidth: 1))
            .shadow(color: on ? app.tint.opacity(0.30) : .clear, radius: 8, x: 0, y: 3)
        }
        .buttonStyle(SBS())
    }

    @ViewBuilder
    private var promptList: some View {
        let prompts = store.selectedApp.promptLibrary
        if store.selectedApp == .other || prompts.isEmpty {
            customPromptCard
        } else {
            VStack(alignment: .leading, spacing: 8) {
                RWSectionLabel("PROMPTS")
                LazyVStack(spacing: 8) {
                    ForEach(prompts, id: \.self) { prompt in
                        promptRow(prompt)
                    }
                }
            }
        }
    }

    private var customPromptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            RWSectionLabel("YOUR PROMPT")
            TextField("Type your prompt", text: $customPromptText)
                .font(RWF.body())
                .foregroundColor(.rwTextPrimary)
                .padding(SP.md)
                .background(Color.rwSurface)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))

            if !customPromptText.trimmingCharacters(in: .whitespaces).isEmpty {
                promptRow(customPromptText)
            }
        }
    }

    @ViewBuilder
    private func promptRow(_ prompt: String) -> some View {
        let isOpen = expandedPrompt == prompt
        let answer = Binding(
            get: { store.savedPromptAnswers[prompt] ?? "" },
            set: { store.savedPromptAnswers[prompt] = $0 }
        )
        let generated = store.generatedPrompts[prompt]

        VStack(alignment: .leading, spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    expandedPrompt = isOpen ? nil : prompt
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LinearGradient.accent)
                        .frame(width: 32, height: 32)
                        .background(Color.rwAccent.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: RR.sm))

                    Text(prompt)
                        .font(RWF.head(14))
                        .foregroundColor(.rwTextPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.rwTextMuted)
                }
            }
            .buttonStyle(SBS())

            if isOpen {
                expandedContent(prompt: prompt, answer: answer, generated: generated)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(SP.md)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(
            RoundedRectangle(cornerRadius: RR.xl)
                .stroke(isOpen ? Color.rwAccent.opacity(0.3) : Color.rwBorder,
                        lineWidth: isOpen ? 1.5 : 1))
    }

    @ViewBuilder
    private func expandedContent(prompt: String,
                                 answer: Binding<String>,
                                 generated: Claude.ProfilePromptOptions?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Your current answer (optional)", systemImage: "pencil")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                TextField("Anything you'd already written…", text: answer, axis: .vertical)
                    .font(RWF.body(14))
                    .foregroundColor(.rwTextPrimary)
                    .lineLimit(1...4)
                    .padding(SP.md)
                    .background(Color.rwSurface)
                    .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                    .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
            }

            if let generated {
                generatedCard(label: "Playful",    emoji: "😄", text: generated.playful,    color: .rwGold)
                generatedCard(label: "Genuine",    emoji: "💙", text: generated.genuine,    color: .rwViolet)
                generatedCard(label: "Intriguing", emoji: "✨", text: generated.intriguing, color: .rwAccent)

                refinementRow(prompt: prompt, currentAnswer: answer.wrappedValue)
            }

            RWButton(loading == prompt
                     ? "Cyrano is writing…"
                     : (generated == nil ? "Generate with Cyrano" : "Generate again"),
                     icon: loading == prompt ? nil : "sparkles") {
                Task { await generate(prompt: prompt, currentAnswer: answer.wrappedValue, refinement: nil) }
            }
            .disabled(loading == prompt)
        }
    }

    private func generatedCard(label: String, emoji: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Text(emoji).font(.system(size: 13))
                    Text(label.uppercased()).font(RWF.micro()).tracking(1.5)
                }
                .foregroundColor(color)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
                Spacer()
                CopyButton(text: text)
            }
            Text(text)
                .font(RWF.body())
                .foregroundColor(.rwTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SP.md)
        .background(Color.rwSurface)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
    }

    private func refinementRow(prompt: String, currentAnswer: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Make it more:", systemImage: "wand.and.stars")
                .font(RWF.cap()).foregroundColor(.rwTextMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    refinementChip("Funnier",      prompt: prompt, currentAnswer: currentAnswer, refinement: "funnier")
                    refinementChip("Bolder",       prompt: prompt, currentAnswer: currentAnswer, refinement: "bolder")
                    refinementChip("Shorter",      prompt: prompt, currentAnswer: currentAnswer, refinement: "shorter")
                    refinementChip("More mysterious", prompt: prompt, currentAnswer: currentAnswer, refinement: "more mysterious")
                }
            }
        }
    }

    private func refinementChip(_ label: String, prompt: String, currentAnswer: String, refinement: String) -> some View {
        Button {
            Task { await generate(prompt: prompt, currentAnswer: currentAnswer, refinement: refinement) }
        } label: {
            Text(label).font(RWF.cap(12))
                .foregroundColor(.rwAccent)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Color.rwAccent.opacity(0.10))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.rwAccent.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(SBS())
        .disabled(loading == prompt)
    }

    // MARK: action

    private func generate(prompt: String, currentAnswer: String, refinement: String?) async {
        if !storeManager.canUseProfilePrompt() {
            showPaywall = true
            return
        }
        loading = prompt
        error = ""
        defer { loading = nil }

        do {
            let result = try await Claude.shared.generatePromptAnswers(
                app: store.selectedApp.rawValue,
                prompt: prompt,
                currentAnswer: currentAnswer,
                refinement: refinement)
            store.generatedPrompts[prompt] = result
            storeManager.trackProfilePromptUsed()
        } catch {
            self.error = "Cyrano couldn't generate a clean version. Try again."
        }
    }
}

// MARK: - Copy Button (shared by Profile Coach tabs)

struct CopyButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = text
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copied = false }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                Text(copied ? "Copied" : "Copy").font(RWF.cap(12))
            }
            .foregroundColor(copied ? .white : .rwTextSecondary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(copied ? Color.rwSuccess : Color.rwCard)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(copied ? Color.clear : Color.rwBorder, lineWidth: 1))
        }
        .buttonStyle(SBS())
    }
}
