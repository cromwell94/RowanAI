import SwiftUI

// MARK: - Relationship Health Check

struct RelHealthView: View {
    @State private var store = RelationshipStore.shared
    @State private var mode: HMode = .history
    @State private var currentCheck = HealthCheck()
    @State private var step = 0
    @State private var isLoading = false

    enum HMode { case history, checking }

    var body: some View {
        switch mode {
        case .history: historyView
        case .checking: checkingView
        }
    }

    var historyView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                RWPageHeader("Relationship Health Check",
                             subtitle: "A quick weekly pulse on how things are feeling. Honest, private, trackable.")

                if store.needsHealthCheck {
                    RWButton("Start This Week's Check-In", icon: "heart.fill") {
                        currentCheck = HealthCheck()
                        step = 0
                        withAnimation { mode = .checking }
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.rwSuccess)
                        Text("Check-in done this week — come back next week.")
                            .font(RWF.body(14)).foregroundColor(.rwTextSecondary)
                    }
                    .padding(SP.md).background(Color.rwSuccess.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                }

                // History
                if let checks = store.relationship?.healthChecks, !checks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        RWSectionLabel("HISTORY")
                        ForEach(checks.sorted { $0.date > $1.date }.prefix(8)) { check in
                            HealthCheckCard(check: check)
                        }
                    }
                }

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg).padding(.top, 12)
        }
    }

    var checkingView: some View {
        VStack(spacing: 0) {
            // Progress
            HStack {
                Button { withAnimation { mode = .history } } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.rwTextSecondary).frame(width: 32, height: 32)
                        .background(Color.rwSurface).clipShape(Circle())
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<HealthCheck.dimensions.count, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(i <= step ? Color.rwAccent : Color.rwBorder)
                            .frame(maxWidth: .infinity).frame(height: 4)
                    }
                }
                Spacer().frame(width: 32)
            }
            .padding(.horizontal, SP.lg).padding(.top, 20).padding(.bottom, 24)

            if step < HealthCheck.dimensions.count {
                let dimension = HealthCheck.dimensions[step]
                VStack(spacing: SP.xl) {
                    VStack(spacing: 8) {
                        Text("This week...").font(RWF.cap()).foregroundColor(.rwTextMuted)
                        Text("How is your \(dimension.lowercased())?")
                            .font(RWF.title(24)).foregroundColor(.rwTextPrimary)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }

                    // Rating buttons
                    VStack(spacing: 10) {
                        ForEach([
                            (5, "Really good", Color(hex: "00BFB3")),
                            (4, "Pretty good", Color(hex: "5B8DEF")),
                            (3, "Okay", Color(hex: "F59E0B")),
                            (2, "Not great", Color(hex: "E8356D").opacity(0.7)),
                            (1, "Struggling", Color(hex: "E8356D"))
                        ], id: \.0) { score, label, color in
                            Button {
                                currentCheck.scores[dimension] = score
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    withAnimation {
                                        if step < HealthCheck.dimensions.count - 1 {
                                            step += 1
                                        } else {
                                            Task { await finishCheck() }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    HStack(spacing: 10) {
                                        Circle().fill(color.opacity(0.15)).frame(width: 10, height: 10)
                                        Text(label).font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                                    }
                                    Spacer()
                                    Text("\(score)").font(.system(size: 22, weight: .black, design: .rounded)).foregroundColor(color)
                                }
                                .padding(SP.md).background(Color.rwCard)
                                .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                                .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(color.opacity(0.15), lineWidth: 1))
                                .shadow(color: color.opacity(0.08), radius: 8, x: 0, y: 3)
                            }
                            .buttonStyle(SBS())
                        }
                    }
                    .padding(.horizontal, SP.xl)
                }
                Spacer()
            } else {
                // Cyrano insight
                ScrollView(showsIndicators: false) {
                    VStack(spacing: SP.lg) {
                        VStack(spacing: 8) {
                            Text("Average this week")
                                .font(RWF.cap()).foregroundColor(.rwTextMuted)
                            Text(String(format: "%.1f", currentCheck.averageScore))
                                .font(.system(size: 64, weight: .black, design: .rounded))
                                .foregroundStyle(LinearGradient.accent)
                            Text(scoreLabel).font(RWF.head(20)).foregroundColor(.rwTextPrimary)
                        }

                        if isLoading {
                            RWLoading(msg: "Cyrano is reflecting...")
                                .frame(height: 100)
                        } else if !currentCheck.cyranoInsight.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    GlowDot()
                                    Text("Cyrano's reflection").font(RWF.micro()).foregroundColor(.rwAccent).tracking(1.5)
                                }
                                Text(currentCheck.cyranoInsight)
                                    .font(RWF.body()).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(SP.lg).background(Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))

                            RWButton("Done") {
                                store.update { $0.healthChecks.insert(currentCheck, at: 0) }
                                withAnimation { mode = .history }
                            }
                            .padding(.bottom, 48)
                        }
                    }
                    .padding(.horizontal, SP.lg).padding(.top, 12)
                }
            }
        }
        .rwBG()
    }

    var scoreLabel: String {
        switch currentCheck.averageScore {
        case 4.5...: return "Thriving ❤️"
        case 3.5...: return "Doing well"
        case 2.5...: return "Could be better"
        case 1.5...: return "Needs attention"
        default:     return "Struggling"
        }
    }

    func finishCheck() async {
        isLoading = true
        let scores = HealthCheck.dimensions.compactMap { d -> String? in
            guard let s = currentCheck.scores[d] else { return nil }
            return "\(d): \(s)/5"
        }.joined(separator: ", ")

        let rel = store.relationship
        let partner = rel?.partnerName ?? "their partner"

        let system = """
        You are Cyrano, a relationship coach. Someone just completed a weekly relationship health check.
        Scores: \(scores)
        Average: \(String(format: "%.1f", currentCheck.averageScore))/5
        Partner: \(partner)

        Give a warm, honest 2-3 sentence reflection on their check-in.
        - If scores are high: celebrate briefly, note what seems to be working
        - If scores are mixed: acknowledge the complexity, offer one gentle observation
        - If scores are low: be compassionate, name what stands out, suggest one small thing
        - If any score is 1-2: gently ask if they want to talk about it more in the Vent section
        Never be clinical. Be a warm, honest friend.
        """

        do {
            currentCheck.cyranoInsight = try await Claude.shared.send(system: system, user: "Reflect on this week's check-in.", max: 250)
        } catch {
            currentCheck.cyranoInsight = "Thanks for checking in. Reflecting on how you're feeling is one of the most important things you can do for your relationship."
        }
        isLoading = false
    }
}

struct HealthCheckCard: View {
    let check: HealthCheck
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(check.date.formatted(date: .abbreviated, time: .omitted))
                    .font(RWF.head(14)).foregroundColor(.rwTextPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Text(String(format: "%.1f", check.averageScore))
                        .font(RWF.display(18)).foregroundStyle(LinearGradient.accent)
                    Text("/ 5").font(RWF.cap()).foregroundColor(.rwTextMuted)
                }
            }
            if !check.cyranoInsight.isEmpty {
                Text(check.cyranoInsight).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true).lineLimit(2)
            }
            // Score bars
            VStack(spacing: 4) {
                ForEach(HealthCheck.dimensions, id: \.self) { d in
                    if let score = check.scores[d] {
                        HStack(spacing: 8) {
                            Text(d).font(RWF.cap(10)).foregroundColor(.rwTextMuted).frame(width: 100, alignment: .leading)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.rwBorder).frame(height: 4)
                                    RoundedRectangle(cornerRadius: 2).fill(LinearGradient.accent)
                                        .frame(width: geo.size.width * CGFloat(score) / 5, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                    }
                }
            }
        }
        .padding(SP.md).background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
        .shadow(color: Color.rwShadow, radius: 6, x: 0, y: 2)
    }
}
