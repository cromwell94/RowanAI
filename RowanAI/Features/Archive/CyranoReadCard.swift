import SwiftUI

// MARK: - Cyrano's Read Card
//
// Lives at the top of ContactDetailView's Overview tab. Shows Cyrano's running
// take on the connection — momentum, stage, flags, guidance, next move.
// Updates automatically (rate-limited to 1/hour) and on manual refresh.
//
// Card states:
//   • notEnoughData — "Add more to this conversation…" placeholder
//   • generating   — pulsing shimmer with "Cyrano is reading…"
//   • ready        — full analysis card
//   • error        — caption with retry

struct CyranoReadCard: View {
    let person: Person

    @State private var analysisStore = AnalysisStore.shared
    @State private var generating = false
    @State private var error: String? = nil
    @State private var greenExpanded = false
    @State private var yellowExpanded = false
    @State private var patternsExpanded = false
    @State private var showHistory = false

    private var current: RelationshipAnalysis? {
        analysisStore.analysis(for: person.id)
    }

    private var hasEnoughData: Bool {
        RelationshipAnalysisService.hasEnoughData(for: person)
    }

    var body: some View {
        Group {
            if generating && current == nil {
                placeholderCard(.shimmer)
            } else if let analysis = current {
                readyCard(analysis)
            } else if !hasEnoughData {
                placeholderCard(.notEnough)
            } else {
                placeholderCard(.idle)
            }
        }
        .onAppear { autoRefreshIfStale() }
        .sheet(isPresented: $showHistory) {
            AnalysisHistorySheet(person: person)
        }
    }

    // MARK: - Ready card

    private func readyCard(_ a: RelationshipAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            // Top row — momentum + stage + refresh
            HStack(spacing: 8) {
                pill(text: "\(a.momentum.emoji) \(a.momentum.rawValue)",
                     tint: a.momentum.color)
                pill(text: a.connectionStage.rawValue,
                     tint: .rwTextSecondary,
                     background: Color.rwSurface)
                Spacer()
                Button { manualRefresh() } label: {
                    Image(systemName: generating ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.rwTextSecondary)
                        .rotationEffect(.degrees(generating ? 360 : 0))
                        .animation(generating
                                   ? .linear(duration: 1).repeatForever(autoreverses: false)
                                   : .default,
                                   value: generating)
                        .frame(width: 28, height: 28)
                        .background(Color.rwSurface)
                        .clipShape(Circle())
                }
                .buttonStyle(SBS())
                .disabled(generating)
            }

            // Overall read
            if !a.overallRead.isEmpty {
                Text(a.overallRead)
                    .font(RWF.body(15))
                    .foregroundColor(.rwTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Flags
            if !a.greenFlags.isEmpty {
                flagSection(title: "Green Flags",
                            icon: "✅",
                            tint: .rwSuccess,
                            items: a.greenFlags,
                            expanded: $greenExpanded)
            }
            if !a.yellowFlags.isEmpty {
                flagSection(title: "Yellow Flags",
                            icon: "⚠️",
                            tint: .rwGold,
                            items: a.yellowFlags,
                            expanded: $yellowExpanded)
            }
            if !a.patterns.isEmpty {
                flagSection(title: "Patterns",
                            icon: "🔄",
                            tint: Color(hex: "5B8DEF"),
                            items: a.patterns,
                            expanded: $patternsExpanded)
            }

            // Guidance
            if !a.currentGuidance.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Right now")
                        .font(RWF.cap(11))
                        .foregroundColor(.rwTextMuted)
                        .tracking(0.5)
                    Text(a.currentGuidance)
                        .font(RWF.head(15))
                        .foregroundColor(.rwTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Next move
            if !a.nextMoveAdvice.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Next move")
                        .font(RWF.cap(11))
                        .foregroundColor(.rwTextMuted)
                        .tracking(0.5)
                    Text(a.nextMoveAdvice)
                        .font(RWF.body(14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(LinearGradient.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Footer
            HStack {
                Text(footerText(for: a))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.rwTextMuted)
                Spacer()
                Button {
                    showHistory = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                        Text("History").font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.rwTextSecondary)
                }
                .buttonStyle(SBS())
            }

            if let error = error {
                Text(error)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.rwDanger)
            }
        }
        .padding(SP.md)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(
            RoundedRectangle(cornerRadius: RR.xl)
                .stroke(LinearGradient(colors: [a.momentum.color, a.momentum.color.opacity(0.35)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing),
                        lineWidth: 2)
        )
    }

    private func flagSection(title: String,
                             icon: String,
                             tint: Color,
                             items: [String],
                             expanded: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.spring(response: 0.3)) { expanded.wrappedValue.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("\(icon) \(title)")
                        .font(RWF.cap())
                        .foregroundColor(tint)
                    Text("\(items.count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(tint)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(tint.opacity(0.15))
                        .clipShape(Capsule())
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.rwTextMuted)
                        .rotationEffect(.degrees(expanded.wrappedValue ? 180 : 0))
                }
            }
            .buttonStyle(SBS())

            if expanded.wrappedValue {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(tint).frame(width: 4, height: 4).padding(.top, 7)
                            Text(item)
                                .font(RWF.body(13))
                                .foregroundColor(.rwTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func pill(text: String, tint: Color, background: Color? = nil) -> some View {
        Text(text)
            .font(RWF.cap())
            .foregroundColor(tint)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(background ?? tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private func footerText(for a: RelationshipAnalysis) -> String {
        let messages = a.sourceMessageCount
        let dates = a.sourceDateCount
        let intel = a.sourceIntelCount
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        let relative = formatter.localizedString(for: a.lastUpdatedAt, relativeTo: Date())
        return "Based on \(messages) message\(messages == 1 ? "" : "s"), \(dates) date\(dates == 1 ? "" : "s"), \(intel) intel note\(intel == 1 ? "" : "s") · Updated \(relative)"
    }

    // MARK: - Placeholder cards

    private enum Placeholder { case notEnough, idle, shimmer }

    private func placeholderCard(_ kind: Placeholder) -> some View {
        let title: String
        let body: String
        let icon: String

        switch kind {
        case .notEnough:
            title = "Cyrano is listening"
            body = "Add a few messages or log a date and Cyrano will give you a full read. The more you add, the more accurate the analysis."
            icon = "ear.fill"
        case .idle:
            title = "Tap refresh for Cyrano's read"
            body = "Cyrano can analyze where this connection stands."
            icon = "sparkles"
        case .shimmer:
            title = "Cyrano is reading the full picture…"
            body = "Pulling together every message, date, and note to give you an honest read."
            icon = "sparkles"
        }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(LinearGradient.accent)
                Text(title)
                    .font(RWF.head(15))
                    .foregroundColor(.rwTextPrimary)
                Spacer()
                if hasEnoughData && kind != .shimmer {
                    Button { manualRefresh() } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.rwAccent)
                    }
                    .buttonStyle(SBS())
                    .disabled(generating)
                }
            }
            Text(body)
                .font(RWF.body(13))
                .foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let error = error {
                Text(error)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.rwDanger)
            }
        }
        .padding(SP.md)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(
            RoundedRectangle(cornerRadius: RR.xl)
                .stroke(LinearGradient.accent, lineWidth: kind == .shimmer ? 2 : 1)
                .opacity(kind == .shimmer ? 0.6 : 0.2)
        )
        .modifier(ShimmerIfNeeded(active: kind == .shimmer))
    }

    // MARK: - Triggers

    private func autoRefreshIfStale() {
        // Auto-generate the very first time we have data and no analysis yet,
        // OR if more than 24h has passed since the last generation. Honors the
        // service-level 1-hour cooldown, so it's safe to call repeatedly.
        guard hasEnoughData else { return }
        if current == nil {
            beginGenerate(force: false)
            return
        }
        if let last = current?.lastUpdatedAt,
           Date().timeIntervalSince(last) > 24 * 60 * 60 {
            beginGenerate(force: false)
        }
    }

    private func manualRefresh() {
        beginGenerate(force: true)
    }

    private func beginGenerate(force: Bool) {
        guard !generating else { return }
        error = nil
        generating = true
        Task {
            do {
                _ = try await RelationshipAnalysisService.shared.generate(for: person, force: force)
                generating = false
            } catch RelationshipAnalysisService.AnalysisError.aiOff {
                generating = false
                error = "Turn AI on in Settings to generate Cyrano's read."
            } catch RelationshipAnalysisService.AnalysisError.insufficientData {
                generating = false
                // No-op — UI will fall through to the not-enough state.
            } catch RelationshipAnalysisService.AnalysisError.parse {
                generating = false
                error = "Cyrano's response was malformed. Try again in a moment."
            } catch {
                generating = false
                self.error = "Couldn't reach Cyrano. Try again in a moment."
            }
        }
    }
}

// MARK: - Shimmer modifier

private struct ShimmerIfNeeded: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        if active {
            content
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0), Color.white.opacity(0.20), Color.white.opacity(0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .rotationEffect(.degrees(20))
                    .offset(x: phase * 400)
                )
                .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                .onAppear {
                    withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                        phase = 1.5
                    }
                }
        } else {
            content
        }
    }
}

// MARK: - Analysis History Sheet

struct AnalysisHistorySheet: View {
    let person: Person
    @Environment(\.dismiss) var dismiss

    private var entries: [RelationshipAnalysis] {
        var all = AnalysisStore.shared.history(for: person.id)
        if let now = AnalysisStore.shared.analysis(for: person.id) {
            all.insert(now, at: 0)
        }
        return all
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    if entries.isEmpty {
                        Text("No history yet — Cyrano hasn't written a read for \(person.name) yet.")
                            .font(RWF.body())
                            .foregroundColor(.rwTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, SP.lg)
                            .padding(.top, 40)
                    } else {
                        ForEach(entries) { entry in
                            historyCard(entry)
                        }
                    }
                }
                .padding(.horizontal, SP.lg)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .rwBG()
            .navigationTitle("Cyrano's Read History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.rwAccent)
                }
            }
        }
    }

    private func historyCard(_ a: RelationshipAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(a.momentum.emoji) \(a.momentum.rawValue)")
                    .font(RWF.cap())
                    .foregroundColor(a.momentum.color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(a.momentum.color.opacity(0.12))
                    .clipShape(Capsule())
                Spacer()
                Text(DateFormatter.localizedString(from: a.lastUpdatedAt,
                                                   dateStyle: .medium,
                                                   timeStyle: .short))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.rwTextMuted)
            }
            Text(a.overallRead)
                .font(RWF.body(14))
                .foregroundColor(.rwTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if !a.connectionStage.rawValue.isEmpty {
                Text(a.connectionStage.rawValue)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.rwTextSecondary)
            }
        }
        .padding(SP.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
    }
}
