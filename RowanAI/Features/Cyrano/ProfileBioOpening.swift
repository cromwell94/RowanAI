import SwiftUI

// MARK: - Bio Tab

struct ProfileBioTab: View {
    @State private var store = ProfileCoachStore.shared
    @State private var loading = false
    @State private var error = ""
    @State private var showPaywall = false
    @State private var showRefine = false
    @State private var refineLoading = false
    @State private var storeManager = StoreManager.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SP.lg) {
                hero
                if !storeManager.isPro { quotaBar }

                inputs

                if !error.isEmpty {
                    Text(error).font(RWF.body(13)).foregroundColor(.rwDanger)
                        .padding(SP.md).background(Color.rwDanger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: RR.md))
                }

                writeButton

                if loading || refineLoading { Dots(msg: refineLoading ? "Refining…" : "Cyrano is writing your bio…") }

                if let bios = store.generatedBios {
                    bioSection(bios)
                        .transition(.opacity)
                }

                Spacer().frame(height: 100)
            }
            .padding(.horizontal, SP.lg)
            .padding(.top, 12)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .profileBioLimit)
        }
        .sheet(isPresented: $showRefine) {
            BioRefinementSheet(onChoose: { refinement in
                showRefine = false
                Task { await generate(refinement: refinement) }
            })
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
        }
        .hideKB()
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BIO WRITER").font(RWF.micro())
                .foregroundStyle(LinearGradient.accent)
                .tracking(1.6)
            Text("Tell Cyrano about you.")
                .font(RWF.title(22))
                .foregroundColor(.rwTextPrimary)
            Text("3 versions: short and punchy, personality-forward, story-based.")
                .font(RWF.body(14))
                .foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var quotaBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(LinearGradient.accent)
            Text("\(storeManager.profileBiosRemainingToday()) free \(storeManager.profileBiosRemainingToday() == 1 ? "bio" : "bios") left today")
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

    private var inputs: some View {
        VStack(alignment: .leading, spacing: SP.md) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Your current bio", systemImage: "text.alignleft")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                TextField(
                    "Paste your current bio or leave blank if starting fresh",
                    text: $store.currentBio,
                    axis: .vertical
                )
                .font(RWF.body(14))
                .foregroundColor(.rwTextPrimary)
                .lineLimit(2...5)
                .padding(SP.md)
                .background(Color.rwSurface)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Three things you want someone to know", systemImage: "list.number")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                TextField(
                    "e.g. I write at sunrise. I make killer soup dumplings. I'm 5+ years sober.",
                    text: $store.bioThreeThings,
                    axis: .vertical
                )
                .font(RWF.body(14))
                .foregroundColor(.rwTextPrimary)
                .lineLimit(2...5)
                .padding(SP.md)
                .background(Color.rwSurface)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("What are you looking for?", systemImage: "scope")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                lookingForPicker
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("What makes you different from other profiles?", systemImage: "sparkle")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                TextField(
                    "Be honest — one sentence is enough.",
                    text: $store.bioDifferent
                )
                .font(RWF.body(14))
                .foregroundColor(.rwTextPrimary)
                .padding(SP.md)
                .background(Color.rwSurface)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
            }
        }
    }

    private var lookingForPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProfileCoachStore.BioLookingFor.allCases) { option in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        store.bioLookingFor = option
                    } label: {
                        Text(option.rawValue).font(RWF.cap(13))
                            .foregroundColor(store.bioLookingFor == option ? .white : .rwTextPrimary)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(store.bioLookingFor == option
                                        ? AnyShapeStyle(Color(hex: "0D0D0D"))
                                        : AnyShapeStyle(Color.rwCard))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(store.bioLookingFor == option ? Color.clear : Color.rwBorder, lineWidth: 1))
                    }
                    .buttonStyle(SBS())
                }
            }
        }
    }

    private var writeButton: some View {
        RWButton(loading ? "Writing…" : "Write My Bio",
                 icon: loading ? nil : "arrow.right") {
            Task { await generate(refinement: nil) }
        }
        .disabled(loading)
    }

    @ViewBuilder
    private func bioSection(_ bios: Claude.ProfileBioOptions) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RWSectionLabel("CYRANO'S DRAFTS")
                Spacer()
                Button { showRefine = true } label: {
                    Label("Refine", systemImage: "wand.and.stars")
                        .font(RWF.cap(12))
                        .foregroundColor(.rwAccent)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.rwAccent.opacity(0.10))
                        .clipShape(Capsule())
                }
                .buttonStyle(SBS())
            }

            bioCard(label: "Short & Punchy",  text: bios.short,       color: .rwAccent)
            bioCard(label: "Personality",     text: bios.personality, color: .rwViolet)
            bioCard(label: "Story-Based",     text: bios.story,       color: .rwGold)
        }
    }

    private func bioCard(label: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label.uppercased())
                    .font(RWF.micro())
                    .foregroundColor(color)
                    .tracking(1.5)
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
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
    }

    // MARK: action

    private func generate(refinement: String?) async {
        if !storeManager.canUseProfileBio() {
            showPaywall = true
            return
        }
        if refinement == nil { loading = true } else { refineLoading = true }
        error = ""
        defer {
            loading = false
            refineLoading = false
        }

        do {
            let result = try await Claude.shared.generateBios(
                currentBio: store.currentBio,
                threeThings: store.bioThreeThings,
                lookingFor: store.bioLookingFor.rawValue,
                different: store.bioDifferent,
                refinement: refinement)
            store.generatedBios = result
            storeManager.trackProfileBioUsed()
        } catch {
            self.error = "Cyrano couldn't generate a clean bio. Try again."
        }
    }
}

// MARK: - Bio Refinement Sheet

struct BioRefinementSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onChoose: (String) -> Void

    private let options: [(String, String, String)] = [
        ("Funnier",          "face.smiling.fill",  "funnier"),
        ("More genuine",     "heart.fill",         "more genuine"),
        ("Shorter",          "scissors",           "shorter"),
        ("Add more personality", "sparkles",       "more personality-forward"),
        ("More mysterious",  "moon.stars.fill",    "more mysterious")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SP.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Make it…")
                    .font(RWF.title(22))
                    .foregroundColor(.rwTextPrimary)
                Text("Cyrano will rewrite all 3 bios in this direction.")
                    .font(RWF.body(13))
                    .foregroundColor(.rwTextSecondary)
            }

            VStack(spacing: 8) {
                ForEach(options, id: \.0) { option in
                    Button {
                        onChoose(option.2)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: option.1)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.rwAccent)
                                .frame(width: 36, height: 36)
                                .background(Color.rwAccent.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: RR.sm))
                            Text(option.0).font(RWF.head(14))
                                .foregroundColor(.rwTextPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.rwTextMuted)
                        }
                        .padding(SP.md)
                        .background(Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                    }
                    .buttonStyle(SBS())
                }
            }
            Spacer()
        }
        .padding(.horizontal, SP.lg)
        .padding(.top, SP.lg)
        .background(Color.rwBackground.ignoresSafeArea())
    }
}

// MARK: - Opening Tab

struct ProfileOpeningTab: View {
    @State private var store = ProfileCoachStore.shared
    @State private var loading: String? = nil
    @State private var globalLoading = false
    @State private var error = ""
    @State private var showPaywall = false
    @State private var storeManager = StoreManager.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SP.lg) {
                hero
                if !storeManager.isPro { quotaBar }

                inputs

                if !error.isEmpty {
                    Text(error).font(RWF.body(13)).foregroundColor(.rwDanger)
                        .padding(SP.md).background(Color.rwDanger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: RR.md))
                }

                generateButton

                if globalLoading { Dots(msg: "Cyrano is writing openers…") }

                if let openers = store.generatedOpeners {
                    openersSection(openers)
                        .transition(.opacity)
                }

                Spacer().frame(height: 100)
            }
            .padding(.horizontal, SP.lg)
            .padding(.top, 12)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .profileOpenerLimit)
        }
        .hideKB()
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OPENING MESSAGE COACH").font(RWF.micro())
                .foregroundStyle(LinearGradient.accent)
                .tracking(1.6)
            Text("Stop sending \"Hey\".")
                .font(RWF.title(22))
                .foregroundColor(.rwTextPrimary)
            Text("Describe their profile. Cyrano writes 3 openers that actually feel written for them.")
                .font(RWF.body(14))
                .foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var quotaBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(LinearGradient.accent)
            Text("\(storeManager.profileOpenersRemainingToday()) free \(storeManager.profileOpenersRemainingToday() == 1 ? "generation" : "generations") left today")
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

    private var inputs: some View {
        VStack(alignment: .leading, spacing: SP.md) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Tell Cyrano about them", systemImage: "person.fill.questionmark")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                TextField(
                    "Describe their profile — what stood out, what they wrote, what photos they have, any prompts they answered",
                    text: $store.profileDescription,
                    axis: .vertical
                )
                .font(RWF.body(14))
                .foregroundColor(.rwTextPrimary)
                .lineLimit(3...8)
                .padding(SP.md)
                .background(Color.rwSurface)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Your opening message (optional)", systemImage: "pencil")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                TextField(
                    "What were you going to send? (leave blank and Cyrano will write from scratch)",
                    text: $store.draftOpener
                )
                .font(RWF.body(14))
                .foregroundColor(.rwTextPrimary)
                .padding(SP.md)
                .background(Color.rwSurface)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
            }
        }
    }

    private var generateButton: some View {
        RWButton(globalLoading ? "Writing…" : "Generate Openers",
                 icon: globalLoading ? nil : "arrow.right") {
            Task { await generate(regenerate: nil) }
        }
        .disabled(globalLoading)
    }

    private func openersSection(_ openers: Claude.ProfileOpenerOptions) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RWSectionLabel("OPENERS")
            openerCard(label: "🎯 Specific", body: openers.specific, color: .rwAccent,  key: "specific")
            openerCard(label: "😄 Playful",  body: openers.playful,  color: .rwGold,    key: "playful")
            openerCard(label: "🤔 Curious",  body: openers.curious,  color: .rwViolet,  key: "curious")
        }
    }

    private func openerCard(label: String, body: String, color: Color, key: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label.uppercased())
                    .font(RWF.micro())
                    .foregroundColor(color)
                    .tracking(1.5)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
                Spacer()
                Button {
                    Task { await generate(regenerate: key) }
                } label: {
                    HStack(spacing: 4) {
                        if loading == key {
                            ProgressView().tint(color).scaleEffect(0.6)
                        } else {
                            Image(systemName: "shuffle").font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        Text("Try a different angle").font(RWF.cap(11))
                    }
                    .foregroundColor(color)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(color.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(SBS())
                .disabled(loading == key)
                CopyButton(text: body)
            }
            Text(body)
                .font(RWF.body())
                .foregroundColor(.rwTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SP.md)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
    }

    // MARK: action

    private func generate(regenerate: String?) async {
        if !storeManager.canUseProfileOpener() {
            showPaywall = true
            return
        }
        if regenerate == nil { globalLoading = true } else { loading = regenerate }
        error = ""
        defer {
            globalLoading = false
            loading = nil
        }

        do {
            let result = try await Claude.shared.generateOpeners(
                profileDescription: store.profileDescription,
                draftOpener: store.draftOpener,
                regenerate: regenerate)
            store.generatedOpeners = result
            storeManager.trackProfileOpenerUsed()
        } catch {
            self.error = "Cyrano couldn't write openers. Try again."
        }
    }
}
