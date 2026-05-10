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
        RWPageHeader("Communication Lab",
                     subtitle: "Frameworks, scripts, and practice for the conversations that matter.",
                     topPadding: 0)
    }

    private var simulatorCard: some View {
        Button {
            startSimulator = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
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
                Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.rwTextMuted)
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
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
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
                Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.rwTextMuted)
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
    let body: String
    let keyInsight: String
    let research: String

    static let all: [CouplesLesson] = [
        .init(id: 1, title: "Five Love Languages in Practice",
              summary: "Knowing yours is half. Speaking theirs is the rest.",
              isPro: false, isAgeGated: false,
              body: "Gary Chapman identified five primary ways people give and receive love: Words of Affirmation, Acts of Service, Receiving Gifts, Quality Time, and Physical Touch. The problem isn't that people don't love each other — it's that they're often expressing love in their own language rather than their partner's. Someone who values Acts of Service will clean the whole house as an expression of love. Their partner who values Words of Affirmation will appreciate the clean house but still feel unloved because nobody said anything. The exercise: each partner ranks the five languages in order. Then deliberately express love in their top language for one week — not yours.",
              keyInsight: "Love expressed in the wrong language doesn't land. Learn their language.",
              research: "Gary Chapman, The Five Love Languages."),
        .init(id: 2, title: "How to Fight Fair — The Four Horsemen",
              summary: "Gottman's predictors of relationship damage and how to defang them.",
              isPro: false, isAgeGated: false,
              body: "John Gottman identified four communication patterns that predict relationship breakdown with over 90% accuracy. Criticism attacks character rather than behavior — \"you're so selfish\" instead of \"I felt hurt when you didn't call.\" Contempt communicates superiority — eye-rolling, mockery, dismissiveness. Defensiveness refuses accountability and counter-attacks. Stonewalling shuts down entirely, usually to manage emotional flooding. The antidotes: gentle startup instead of criticism, building a culture of appreciation to counter contempt, taking responsibility for even a small part of the issue, and physiological self-soothing during stonewalling — taking a 20-minute break before returning.",
              keyInsight: "Learn to recognize your own Four Horsemen pattern before your partner's.",
              research: "John Gottman, Why Marriages Succeed or Fail."),
        .init(id: 3, title: "Repair Attempts",
              summary: "How couples come back from conflict — and what blocks repair.",
              isPro: false, isAgeGated: false,
              body: "A repair attempt is any word, gesture, or action that tries to reduce tension during conflict. \"Can we slow down?\" \"I'm feeling defensive right now.\" A touch on the hand. A shared joke. Gottman found that the success rate of repair attempts — not their frequency — is the single best predictor of long-term relationship health. Failed repairs happen when one partner is too emotionally flooded to receive them. The key is learning what repairs work for your specific partner and making them before the conversation escalates beyond the point of return. The 20-minute rule: if either person is flooded, stop and return when calm.",
              keyInsight: "Practice repairs before you need them so they work when you do.",
              research: "John Gottman, The Seven Principles for Making Marriage Work."),
        .init(id: 4, title: "The Bids for Connection",
              summary: "The small moments that build (or erode) trust over time.",
              isPro: true, isAgeGated: false,
              body: "John Gottman identified the bid as the fundamental unit of emotional connection. A bid is any attempt — large or small — to connect with your partner. \"Look at this\" while showing your phone. A question about their day. Reaching for their hand. The response matters enormously: turning toward acknowledges the bid, turning away ignores it, turning against meets it with irritation. Couples who turn toward each other's bids 86% of the time in daily life are still together six years later. Couples who turn toward only 33% of the time are divorced. Most relationship erosion is not dramatic — it's thousands of small turning-away moments that accumulate into distance.",
              keyInsight: "Notice and respond to small bids. They are the relationship.",
              research: "John Gottman, The Relationship Cure."),
        .init(id: 5, title: "The Dreams Within Conflict",
              summary: "Most recurring fights are about hidden dreams, not surface issues.",
              isPro: true, isAgeGated: false,
              body: "Beneath most recurring arguments is a hidden dream — a deeply held value, need, or life vision that isn't being honored. Couples who keep fighting about money are rarely fighting about money. One partner's dream might be security. The other's might be freedom and spontaneity. Until both dreams are named and genuinely respected the argument recycles indefinitely. The unlocking question is not \"why are you being difficult\" but \"help me understand why this matters so much to you.\" When the dream beneath the position becomes visible the conversation changes completely — from opposing positions to shared problem-solving.",
              keyInsight: "Ask what dream is hiding beneath the recurring argument.",
              research: "John Gottman, The Seven Principles for Making Marriage Work."),
        .init(id: 6, title: "Desire and Distance",
              summary: "The paradox of long-term love: safety and eroticism pull in opposite directions.",
              isPro: true, isAgeGated: false,
              body: "Esther Perel's central insight reframes a painful paradox: the things that create safety in long-term relationships — predictability, availability, total familiarity — are the exact opposite of what maintains erotic charge. This is not a design flaw. It is the central tension every long-term couple must navigate consciously. The solution is not manufactured distance but maintained separateness — individual interests, time apart, the capacity to see your partner as someone still slightly unknowable. \"I can miss my partner even when they're home\" is a skill. Couples who maintain some mystery and individual identity consistently report higher long-term desire than couples who merge completely.",
              keyInsight: "Maintain separateness. You cannot desire what you already completely possess.",
              research: "Esther Perel, Mating in Captivity."),
        .init(id: 7, title: "The Softened Startup",
              summary: "How a hard conversation begins predicts how it ends.",
              isPro: true, isAgeGated: false,
              body: "How a difficult conversation begins predicts how it ends with startling consistency. A harsh startup — beginning with criticism, blame, or contempt — almost guarantees escalation and shutdown. The softened startup uses a specific formula: I feel [emotion] about [specific situation]. I need [specific request]. Not \"you never listen to me\" but \"I feel disconnected when we're both on our phones at dinner. I'd love us to try phone-free meals.\" The difference is ownership of feeling, specificity about the situation, and a concrete request instead of a character indictment. Practice writing the softened version of your most common harsh startup.",
              keyInsight: "Start hard conversations with feelings and requests, never character criticism.",
              research: "John Gottman, The Four Horsemen. Marshall Rosenberg, Nonviolent Communication."),
        .init(id: 8, title: "Turning Toward in the Small Moments",
              summary: "The ten thousand ordinary moments that hold a relationship up.",
              isPro: true, isAgeGated: false,
              body: "The romantic grand gestures get attention. The small daily moments do the actual work. Making eye contact when your partner enters the room. Putting the phone down when they start talking. Remembering something they mentioned last week and asking about it today. These micro-moments of attunement accumulate into what Gottman calls the sound relationship house — a foundation strong enough to hold the inevitable hard seasons without cracking. The couples who stay together are not the ones who never struggle. They are the ones who kept turning toward each other in the ten thousand ordinary moments that no one witnesses.",
              keyInsight: "The small daily moments of attention matter more than the big romantic gestures.",
              research: "John Gottman, The Relationship Cure."),
        .init(id: 9, title: "Apologizing Well",
              summary: "Most apologies are inadequate. Here's the structure that actually repairs.",
              isPro: true, isAgeGated: false,
              body: "Most apologies are inadequate. \"I'm sorry you feel that way\" is not an apology — it makes their feelings the problem. \"I'm sorry but...\" negates everything before it. A real apology requires three things in sequence: acknowledgment of the specific thing you did, genuine understanding of why it hurt this particular person, and a credible commitment to do differently. The hardest part is the middle — actually trying to understand the impact from their perspective, not just feeling bad about the outcome. A well-delivered apology does not just repair the moment. It builds evidence that future moments can be repaired too, which is what creates long-term safety.",
              keyInsight: "Acknowledge, understand, commit. In that order. Never \"but.\"",
              research: "Harriet Lerner, Why Won't You Apologize?"),
        .init(id: 10, title: "The Relationship Vision",
              summary: "Have the meta-conversation before you need to.",
              isPro: true, isAgeGated: false,
              body: "Couples who stay intentional about where they are going fare better than couples who let the relationship evolve entirely by default. A shared relationship vision is not a rigid plan — it is a set of values and intentions made explicit together. What kind of home do we want to create? How do we want to handle conflict when it comes? What does a genuinely good week look like for both of us? These conversations had proactively rather than reactively create alignment before misalignment becomes a crisis. Logan Ury recommends a quarterly relationship check-in: a dedicated conversation about what is working, what needs attention, and what you are both looking forward to building together.",
              keyInsight: "Have the meta-conversation about the relationship before you need to.",
              research: "Logan Ury, How to Not Die Alone. Stan Tatkin, Wired for Love."),
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
                    Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.rwTextMuted)
                }
            }
            .padding(SP.md).background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Lesson Detail (hardcoded body + key insight + research)

struct CouplesLessonView: View {
    let lesson: CouplesLesson
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SP.lg) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LESSON \(lesson.id)")
                            .font(RWF.micro()).foregroundColor(.rwTextMuted).tracking(1.4)
                        Text(lesson.title).font(RWF.title()).foregroundColor(.rwTextPrimary)
                        Text(lesson.summary).font(RWF.body()).foregroundColor(.rwTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider()

                    Text(lesson.body)
                        .font(RWF.body(15)).foregroundColor(.rwTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(5)

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.rwGold)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Key insight").font(RWF.cap()).foregroundColor(.rwTextMuted).tracking(1.2)
                            Text(lesson.keyInsight)
                                .font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                                .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
                        }
                    }
                    .padding(SP.md).background(Color.rwGold.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                    .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwGold.opacity(0.25), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Research", systemImage: "books.vertical.fill")
                            .font(RWF.cap()).foregroundColor(.rwTextMuted)
                        Text(lesson.research)
                            .font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                            .italic()
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer().frame(height: 40)
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
                        .font(.system(size: 48, design: .rounded)).foregroundColor(Color.rwGold)
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
