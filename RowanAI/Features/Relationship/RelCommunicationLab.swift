import SwiftUI

// MARK: - Couples Communication Lab (Build 1 Step 6, Pillar 2)
// 10 lessons (1-3 free, 4-10 Pro). Couples Simulator scenarios use the live
// relationship data (partner name, duration, recent health checks). The
// "Difficult Conversation Simulator" full feature is a Build 2 stub today.

struct RelCommunicationLab: View {
    @State private var store = RelationshipStore.shared
    @State private var showPaywall = false
    @State private var selectedLesson: CouplesLesson? = nil
    @State private var startSimulator = false
    @State private var startDifficult = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                hero
                simulatorCard
                difficultStubCard
                lessonsSection
                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg).padding(.top, 16)
        }
        .rwBG()
        .sheet(item: $selectedLesson) { lesson in
            CouplesLessonView(lesson: lesson)
        }
        .sheet(isPresented: $showPaywall) { PaywallView(reason: .upgrade) }
        .sheet(isPresented: $startSimulator) {
            CouplesSimulatorView()
        }
        .sheet(isPresented: $startDifficult) {
            DifficultConversationStubView()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Communication Lab").font(RWF.title()).foregroundColor(.rwTextPrimary)
            Text("Frameworks, scripts, and practice for the conversations that matter.")
                .font(RWF.body()).foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var simulatorCard: some View {
        Button {
            startSimulator = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(LinearGradient.accent)
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Couples Simulator").font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                    Text("Practice scenarios using your real relationship context.")
                        .font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
            }
            .padding(SP.lg).background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
            .shadow(color: Color.rwShadow, radius: 12, x: 0, y: 2)
        }
        .buttonStyle(SBS())
    }

    private var difficultStubCard: some View {
        Button { startDifficult = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.rwGold)
                    .frame(width: 52, height: 52)
                    .background(Color.rwGold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Difficult Conversation Simulator")
                            .font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                        Text("BUILD 2").font(RWF.micro())
                            .foregroundColor(.rwTextMuted)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.rwBorder.opacity(0.5))
                            .clipShape(Capsule())
                    }
                    Text("Describe what needs saying — Cyrano builds a custom partner avatar to practice with.")
                        .font(RWF.body(12)).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
            }
            .padding(SP.lg).background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
        }
        .buttonStyle(SBS())
    }

    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            RWSectionLabel("LESSONS")
            VStack(spacing: 8) {
                ForEach(CouplesLesson.all) { lesson in
                    let locked = lesson.isPro && !StoreManager.shared.isPro
                    RelLessonRow(lesson: lesson, locked: locked) {
                        if locked { showPaywall = true } else { selectedLesson = lesson }
                    }
                }
            }
        }
    }
}

// MARK: - Lesson Model

struct CouplesLesson: Identifiable, Hashable {
    let id: Int
    let title: String
    let summary: String
    let isPro: Bool
    let isAgeGated: Bool

    static let all: [CouplesLesson] = [
        .init(id: 1,  title: "Five Love Languages in Practice",
              summary: "Knowing yours is half. Speaking theirs is the rest.",
              isPro: false, isAgeGated: false),
        .init(id: 2,  title: "How to Fight Fair — The Four Horsemen",
              summary: "Gottman's predictors of relationship damage and how to defang them.",
              isPro: false, isAgeGated: false),
        .init(id: 3,  title: "Repair Attempts",
              summary: "How couples come back from conflict — and what blocks repair.",
              isPro: false, isAgeGated: false),
        .init(id: 4,  title: "Bids for Connection",
              summary: "The small moments that build (or erode) trust over time.",
              isPro: true, isAgeGated: false),
        .init(id: 5,  title: "The Art of Listening",
              summary: "Listening to understand vs. listening to respond.",
              isPro: true, isAgeGated: false),
        .init(id: 6,  title: "Expressing Needs Without Demanding",
              summary: "How to ask for what you need without making them feel cornered.",
              isPro: true, isAgeGated: false),
        .init(id: 7,  title: "Intimacy Beyond Physical",
              summary: "Emotional, intellectual, and shared-world intimacy.",
              isPro: true, isAgeGated: false),
        .init(id: 8,  title: "Sexual Communication",
              summary: "Talking about desire, boundaries, and pleasure.",
              isPro: true, isAgeGated: true),
        .init(id: 9,  title: "Handling Conflict About Money",
              summary: "Money as a proxy for power, fear, and family history.",
              isPro: true, isAgeGated: false),
        .init(id: 10, title: "Navigating Perpetual Differences",
              summary: "69% of conflicts are perpetual. Here's how to live with them.",
              isPro: true, isAgeGated: false),
    ]
}

private struct RelLessonRow: View {
    let lesson: CouplesLesson
    let locked: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.rwGold.opacity(0.12)).frame(width: 36, height: 36)
                    Text("\(lesson.id)")
                        .font(RWF.head(14)).foregroundColor(.rwGold)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(lesson.title).font(RWF.head(14)).foregroundColor(.rwTextPrimary)
                            .lineLimit(2)
                        if lesson.isAgeGated {
                            Text("18+").font(RWF.micro()).foregroundColor(.rwTextMuted)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.rwBorder.opacity(0.6)).clipShape(Capsule())
                        }
                    }
                    Text(lesson.summary).font(RWF.body(12)).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if locked {
                    Image(systemName: "lock.fill").foregroundColor(.rwTextMuted)
                } else {
                    Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
                }
            }
            .padding(SP.md).background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Lesson Detail (scaffold; Cyrano writes the body on open)

struct CouplesLessonView: View {
    let lesson: CouplesLesson
    @Environment(\.dismiss) private var dismiss
    @State private var body_: String = ""
    @State private var loading = true

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SP.md) {
                    Text(lesson.title).font(RWF.title()).foregroundColor(.rwTextPrimary)
                    Text(lesson.summary).font(RWF.body()).foregroundColor(.rwTextSecondary)
                    Divider().padding(.vertical, 8)
                    if loading && body_.isEmpty {
                        HStack { ProgressView(); Text("Cyrano is writing this…").font(RWF.body(14)).foregroundColor(.rwTextMuted) }
                    } else {
                        Text(body_)
                            .font(RWF.body()).foregroundColor(.rwTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(SP.lg)
            }
            .rwBG()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.rwAccent)
                }
            }
            .task { await loadLesson() }
        }
    }

    private func loadLesson() async {
        loading = true
        defer { loading = false }
        guard AISettings.shared.isEnabled else {
            body_ = lesson.summary
            return
        }
        let role = """
        YOUR ROLE NOW: Couples-mode lesson author.
        Topic: \(lesson.title).
        Summary: \(lesson.summary).
        Write the lesson body — 3-4 short paragraphs, ~250 words total, plain text, no headers.
        Specific, practical, warm. No jargon. End with one short prompt the couple can try this week.
        """
        do {
            let raw = try await Claude.shared.send(system: role,
                                                   user: "Write the lesson.",
                                                   max: 600)
            body_ = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            body_ = lesson.summary
        }
    }
}

// MARK: - Couples Simulator (scenario practice using live relationship data)

struct CouplesSimulatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = RelationshipStore.shared
    @State private var scenario = ""
    @State private var generating = false
    @State private var output = ""

    private let starters: [String] = [
        "I want to ask for more presence in the evenings",
        "We keep fighting about chores — same script every time",
        "I want to bring up something they did that hurt me",
        "I need to talk about money pressure",
        "We're not having sex and neither of us is talking about it",
    ]

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SP.md) {
                    Text("Scenario").font(RWF.cap()).foregroundColor(.rwTextMuted)
                    TextField("", text: $scenario,
                              prompt: Text("Describe what you want to practice…").foregroundColor(.rwTextMuted),
                              axis: .vertical)
                        .lineLimit(3...6)
                        .font(RWF.body()).foregroundColor(.rwTextPrimary)
                        .padding(SP.md).background(Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))

                    Text("Quick starts").font(RWF.cap()).foregroundColor(.rwTextMuted).padding(.top, 4)
                    ForEach(starters, id: \.self) { s in
                        Button { scenario = s } label: {
                            HStack {
                                Text(s).font(RWF.body(13)).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                            .padding(SP.md).background(Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.md))
                        }
                        .buttonStyle(SBS())
                    }

                    if !output.isEmpty {
                        Divider().padding(.vertical, 8)
                        Text("How to open this conversation").font(RWF.head()).foregroundColor(.rwTextPrimary)
                        Text(output).font(RWF.body()).foregroundColor(.rwTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    RWButton(generating ? "Building…" : "Get Cyrano's script", icon: "wand.and.stars") {
                        Task { await generate() }
                    }
                    .disabled(scenario.trimmingCharacters(in: .whitespaces).isEmpty || generating)
                    .padding(.top, 12)
                }
                .padding(SP.lg)
            }
            .rwBG()
            .navigationTitle("Couples Simulator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.rwAccent)
                }
            }
        }
    }

    private func generate() async {
        guard AISettings.shared.isEnabled else { return }
        generating = true
        defer { generating = false }
        let user = AuthService.shared.currentUser
        let partnerName = user?.partnerName ?? store.relationship?.partnerName ?? "your partner"
        let duration = user?.relationshipDuration?.rawValue ?? "an unspecified duration"
        let role = """
        YOUR ROLE NOW: Couples coach.
        The user is partnered with \(partnerName), together \(duration).
        They want to practice this conversation: "\(scenario)"
        Write a 4-6 sentence opener they could actually say tonight. Soft on the bid, specific on the need, no blame, no over-explaining. Conversational — not a script. End with what to listen for in the partner's response.
        """
        do {
            let raw = try await Claude.shared.send(system: role, user: scenario, max: 400)
            output = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            output = "Something is keeping us from connecting on this. I want to talk about it without it turning into a fight. Can we?"
        }
    }
}

// MARK: - Difficult Conversation Stub

struct DifficultConversationStubView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .font(.system(size: 48)).foregroundColor(Color.rwGold)
                        .padding(.top, 32)
                    Text("Difficult Conversation Simulator")
                        .font(RWF.title()).foregroundColor(.rwTextPrimary)
                        .multilineTextAlignment(.center)
                    Text("Coming in Build 2.")
                        .font(RWF.cap()).foregroundColor(.rwTextMuted)
                    RWCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("How it will work", systemImage: "list.bullet")
                                .font(RWF.cap()).foregroundColor(.rwTextMuted)
                            Text("Describe what happened, what you need them to understand, and what you're afraid they'll say. Cyrano builds a custom partner avatar — and you practice. Mid-conversation Cyrano can step in with a coaching note. Repeat as many times as needed.")
                                .font(RWF.body()).foregroundColor(.rwTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(SP.lg)
            }
            .rwBG()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.rwAccent)
                }
            }
        }
    }
}
