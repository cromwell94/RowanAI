import SwiftUI

// MARK: - Conversation Coach Main View

struct ConversationCoachView: View {
    @State private var mode: CoachMode = .menu
    @State private var on = false

    enum CoachMode { case menu, practice, lessons, game }

    var body: some View {
        switch mode {
        case .menu:     menuView
        case .practice: PracticeView { mode = .menu }
        case .lessons:  LessonsView  { mode = .menu }
        case .game:     GameView     { mode = .menu }
        }
    }

    var menuView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Conversation\nCoach").font(RWF.display(30)).foregroundColor(.rwTextPrimary)
                    Text("Learn to talk. Practice it. Make it yours.")
                        .font(RWF.body()).foregroundColor(.rwTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(on ? 1 : 0).offset(y: on ? 0 : 10)

                // Mode cards
                VStack(spacing: 14) {
                    CoachModeCard(
                        icon: "person.2.fill",
                        title: "Practice Mode",
                        subtitle: "Cyrano plays the other person. You practice real scenarios and get feedback.",
                        color: Color(hex: "E8356D"),
                        tag: "Interactive"
                    ) { withAnimation { mode = .practice } }

                    CoachModeCard(
                        icon: "book.fill",
                        title: "Lessons",
                        subtitle: "Bite-sized coaching on what works and why. Swipeable cards, quick wins.",
                        color: Color(hex: "5B8DEF"),
                        tag: "Learn"
                    ) { withAnimation { mode = .lessons } }

                    CoachModeCard(
                        icon: "bolt.fill",
                        title: "Challenge Mode",
                        subtitle: "Timed challenges. Cyrano scores your messages and explains what worked.",
                        color: Color(hex: "00BFB3"),
                        tag: "Game"
                    ) { withAnimation { mode = .game } }
                }
                .opacity(on ? 1 : 0)

                // Quick tip
                RWCard {
                    HStack(spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 20, design: .rounded))
                            .foregroundColor(Color(hex: "F59E0B"))
                            .frame(width: 44, height: 44)
                            .background(Color(hex: "F59E0B").opacity(0.1))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 6) {
                            RWSectionLabel("DAILY TIP", accent: true)
                            Text("The best openers are specific. Reference something real in their profile — not just 'hey'.")
                                .font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .opacity(on ? 1 : 0)

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg).padding(.top, 20)
        }
        .rwBG()
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { on = true } }
    }
}

struct CoachModeCard: View {
    let icon: String; let title: String; let subtitle: String
    let color: Color; let tag: String; let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                    .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title).font(RWF.head(17)).foregroundColor(.rwTextPrimary)
                        Text(tag).font(RWF.micro())
                            .foregroundColor(color)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(color.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    Text(subtitle).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.rwTextMuted).padding(.top, 16)
            }
            .padding(SP.lg).background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
            .shadow(color: Color.rwShadow, radius: 12, x: 0, y: 2)
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Practice Mode

struct PracticeView: View {
    let onBack: () -> Void
    @State private var scenario: Scenario? = nil
    @State private var messages: [PracticeMessage] = []
    @State private var input = ""
    @State private var isLoading = false
    @State private var feedback = ""
    @State private var showFeedback = false
    @State private var sessionDone = false
    @FocusState private var focused: Bool

    let scenarios: [Scenario] = [
        Scenario(id: "1", title: "Write the first message",
            description: "They just matched with you. Their bio mentions hiking and bad reality TV. Write the opener.",
            systemContext: "You are playing a dating app match. The user just matched with you. Your profile mentions hiking and loving bad reality TV. Respond naturally as this person would. After 3-4 exchanges, evaluate the conversation and give honest coaching feedback on what worked, what didn't, and one specific thing to improve. Keep responses short — 1-2 sentences like a real text.",
            difficulty: "Beginner"),
        Scenario(id: "2", title: "Ask for their number",
            description: "You've been talking for 3 days. Conversation is going well. Ask for the number naturally.",
            systemContext: "You are playing a dating app match. The conversation has been going well for a few days. The user is trying to naturally transition to asking for your number. Respond as a real person would — warm but not too easy. After they ask for the number (or after 4 exchanges), evaluate how natural and confident they came across. Give specific feedback.",
            difficulty: "Intermediate"),
        Scenario(id: "3", title: "Recover from being left on read",
            description: "You sent a message 4 days ago. No response. Try to re-engage without being desperate.",
            systemContext: "You are a dating app match who left the user on read for 4 days. You were busy but still interested. The user is trying to re-engage. Respond realistically. After 2-3 exchanges, evaluate whether their re-engagement message was confident and non-desperate or came across as needy. Give direct coaching.",
            difficulty: "Intermediate"),
        Scenario(id: "4", title: "Suggest the first date",
            description: "Great conversation. You want to move to an in-person date. Make it happen.",
            systemContext: "You are a dating app match enjoying a great conversation. The user wants to suggest meeting up. Respond as someone who's interested but wants to see how they handle proposing the date. After they suggest a date (or after 3 exchanges), evaluate how confident, specific, and appealing their date suggestion was.",
            difficulty: "Advanced"),
        Scenario(id: "5", title: "Handle a dry conversation",
            description: "They keep giving one-word answers. Turn it around.",
            systemContext: "You are a dating app match giving short, unengaged responses. You're not uninterested, just a bit reserved. The user is trying to get the conversation going. After 4 exchanges, evaluate whether they managed to create genuine engagement or just matched your low energy.",
            difficulty: "Advanced")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.rwTextPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.rwSurface)
                        .clipShape(Circle())
                }
                Spacer()
                Text("Practice Mode").font(RWF.head()).foregroundColor(.rwTextPrimary)
                Spacer()
                if scenario != nil {
                    Button("End") {
                        withAnimation { sessionDone = true }
                        Task { await getFinalFeedback() }
                    }
                    .font(RWF.cap()).foregroundColor(.rwAccent)
                } else {
                    Spacer().frame(width: 36)
                }
            }
            .padding(.horizontal, SP.lg).padding(.vertical, 14)

            RWLine()

            if scenario == nil {
                // Scenario picker
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        Text("Pick a scenario to practice")
                            .font(RWF.head()).foregroundColor(.rwTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        ForEach(scenarios) { s in
                            Button { withAnimation { scenario = s; messages = [] } } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            Text(s.title).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                                            Text(s.difficulty).font(RWF.micro())
                                                .foregroundColor(diffColor(s.difficulty))
                                                .padding(.horizontal, 8).padding(.vertical, 3)
                                                .background(diffColor(s.difficulty).opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                        Text(s.description).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
                                }
                                .padding(SP.md).background(Color.rwCard)
                                .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                                .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
                                .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
                            }
                            .buttonStyle(SBS())
                        }
                        Spacer().frame(height: 80)
                    }
                    .padding(.horizontal, SP.lg).padding(.top, 16)
                }
                .rwBG()
            } else if showFeedback || sessionDone {
                // Feedback view
                ScrollView(showsIndicators: false) {
                    VStack(spacing: SP.lg) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 52, design: .rounded)).foregroundColor(Color(hex: "00BFB3"))
                            .padding(.top, 32)

                        Text("Cyrano's Feedback")
                            .font(RWF.title()).foregroundColor(.rwTextPrimary)

                        if isLoading {
                            RWLoading(msg: "Analyzing your conversation...")
                                .frame(height: 100)
                        } else if !feedback.isEmpty {
                            RWCard {
                                Text(feedback).font(RWF.body()).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        RWButton("Try Another Scenario") {
                            withAnimation { scenario = nil; messages = []; feedback = ""; showFeedback = false; sessionDone = false }
                        }
                        .padding(.bottom, 48)
                    }
                    .padding(.horizontal, SP.lg)
                }
                .rwBG()
            } else {
                // Chat view
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            // Scenario context
                            Text(scenario?.description ?? "")
                                .font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                                .multilineTextAlignment(.center)
                                .padding(SP.md).background(Color.rwSurface)
                                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                                .padding(.horizontal, SP.lg).padding(.top, 12)

                            ForEach(messages) { msg in
                                HStack {
                                    if msg.isUser { Spacer(minLength: 60) }
                                    Text(msg.text).font(RWF.body())
                                        .foregroundColor(msg.isUser ? .white : .rwTextPrimary)
                                        .padding(.horizontal, 14).padding(.vertical, 10)
                                        .background(msg.isUser ? Color.rwAccent : Color.rwSurface)
                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                    if !msg.isUser { Spacer(minLength: 60) }
                                }
                                .padding(.horizontal, SP.lg)
                                .id(msg.id)
                            }

                            if isLoading {
                                HStack {
                                    HStack(spacing: 4) {
                                        ForEach(0..<3, id: \.self) { i in
                                            Circle().fill(Color.rwTextMuted).frame(width: 7, height: 7)
                                        }
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 12)
                                    .background(Color.rwSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    Spacer()
                                }
                                .padding(.horizontal, SP.lg)
                            }

                            Spacer().frame(height: 80)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let last = messages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }
                }
                .rwBG()

                // Input
                RWLine()
                HStack(spacing: 12) {
                    TextField("", text: $input, prompt: Text("Type your message...").foregroundColor(.rwTextMuted))
                        .font(RWF.body()).foregroundColor(.rwTextPrimary).focused($focused)
                        .onSubmit { Task { await send() } }
                    Button { Task { await send() } } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30, design: .rounded))
                            .foregroundColor(input.isEmpty ? .rwTextMuted : .rwAccent)
                    }
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(SBS())
                }
                .padding(.horizontal, SP.lg).padding(.vertical, 14).background(Color.rwBackground)
            }
        }
        .rwBG()
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true } }
    }

    func diffColor(_ d: String) -> Color {
        switch d {
        case "Beginner":     return Color(hex: "00BFB3")
        case "Intermediate": return Color(hex: "F59E0B")
        default:             return Color(hex: "E8356D")
        }
    }

    func send() async {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let s = scenario else { return }
        messages.append(PracticeMessage(text: text, isUser: true))
        input = ""
        isLoading = true

        let history = messages.map { "\($0.isUser ? "User" : "Cyrano"): \($0.text)" }.joined(separator: "\n")

        do {
            let reply = try await Claude.shared.send(
                system: s.systemContext,
                user: "Conversation so far:\n\(history)\n\nRespond as the match would. If it's time for feedback, give it.",
                max: 300)
            messages.append(PracticeMessage(text: reply, isUser: false))
            if reply.lowercased().contains("feedback") || messages.count >= 10 {
                withAnimation { sessionDone = true }
                feedback = reply
            }
        } catch {
            messages.append(PracticeMessage(text: "Something went wrong. Try again.", isUser: false))
        }
        isLoading = false
    }

    func getFinalFeedback() async {
        guard let s = scenario else { return }
        isLoading = true
        let history = messages.map { "\($0.isUser ? "User" : "Match"): \($0.text)" }.joined(separator: "\n")
        do {
            feedback = try await Claude.shared.send(
                system: "You are Cyrano, a conversation coach. Review this practice conversation and give honest, specific coaching feedback. What worked well? What should they improve? Give one concrete tip they can apply immediately. Be encouraging but direct.",
                user: "Scenario: \(s.title)\n\nConversation:\n\(history)",
                max: 400)
        } catch { feedback = "Couldn't load feedback. Try again." }
        isLoading = false
    }
}

struct Scenario: Identifiable {
    let id: String; let title: String; let description: String
    let systemContext: String; let difficulty: String
}

struct PracticeMessage: Identifiable {
    let id = UUID(); let text: String; let isUser: Bool
}

// MARK: - Lessons View

struct LessonsView: View {
    let onBack: () -> Void
    @State private var category: LessonCategory? = nil

    let categories: [LessonCategory] = [
        LessonCategory(title: "First Messages", icon: "hand.wave.fill", color: Color(hex: "E8356D"),
            lessons: [
                Lesson(title: "The 3-second rule", body: "The best first messages feel like they took 3 seconds to write — not 3 minutes. Effort shows, but so does overthinking. Aim for natural, not perfect."),
                Lesson(title: "Be specific, not generic", body: "'Hey' gets deleted. 'You hike and love trash TV — that's the exact right combination' gets a reply. Reference something real from their profile."),
                Lesson(title: "End with energy, not a question mark", body: "Questions can feel like homework. A statement that invites response — 'that hiking photo has me curious about the story behind it' — creates more natural conversation."),
                Lesson(title: "The biggest mistake", body: "Complimenting their appearance first. It signals you only looked at photos. Lead with something from their bio or prompts — then compliment if at all."),
                Lesson(title: "Humor is earned, not assumed", body: "Jokes in openers can backfire hard with the wrong person. A light, playful tone is safer than a full bit. Read their profile energy first.")
            ]),
        LessonCategory(title: "Moving to a Date", icon: "calendar.badge.plus", color: Color(hex: "5B8DEF"),
            lessons: [
                Lesson(title: "The 5-day rule", body: "If you haven't suggested meeting after 5 days of good conversation, momentum starts dying. Matches that don't meet within 2 weeks rarely do."),
                Lesson(title: "Suggest, don't ask permission", body: "'Want to get coffee sometime?' is weak. 'I know a good spot in Williamsburg — free Thursday?' is confident. Specificity signals you've thought about it."),
                Lesson(title: "Give two options", body: "Instead of 'are you free this week?' try 'Tuesday evening or Saturday afternoon work for you?' Two options reduces decision fatigue and signals initiative."),
                Lesson(title: "Location matters", body: "First dates should be walkable, low-pressure, 60-90 minutes max. Coffee, a drink, a walk. Not dinner — too much pressure for a first meeting."),
                Lesson(title: "Don't over-plan", body: "Suggesting a specific bar or coffee shop is perfect. A full itinerary is weird. Leave room for the date to develop naturally.")
            ]),
        LessonCategory(title: "Reading Signals", icon: "eye.fill", color: Color(hex: "00BFB3"),
            lessons: [
                Lesson(title: "Response time is data", body: "Someone responding within minutes for days, then suddenly going to hours — something changed. Not always bad, but worth noting."),
                Lesson(title: "Message length mirrors interest", body: "They were writing paragraphs, now it's one word. That's a signal. People match the energy they want to receive."),
                Lesson(title: "Questions = investment", body: "Someone who asks questions back is invested. Someone who only answers is keeping options open. Count the questions over a full conversation."),
                Lesson(title: "The reschedule test", body: "They cancel a date. Do they immediately suggest another time? If yes — still interested. If they just say 'sorry' with no alternative — that's your answer."),
                Lesson(title: "Gut feelings are real data", body: "If something feels off, it probably is. Your nervous system picks up on inconsistencies faster than your conscious mind. Trust discomfort.")
            ]),
        LessonCategory(title: "Recovering Situations", icon: "arrow.counterclockwise", color: Color(hex: "F59E0B"),
            lessons: [
                Lesson(title: "Left on read: wait, then be light", body: "Wait 3-5 days minimum. Then send something completely unrelated — a funny observation, not a 'hey you okay?' Desperation is the only thing that guarantees no reply."),
                Lesson(title: "After a bad date", body: "If you still want to see them, follow up with something light within 24 hours. Don't reference the awkward moments — just forward motion."),
                Lesson(title: "The over-texter recovery", body: "You sent 3 unanswered messages. Stop. Wait a week. If you reach out again, make it so good it justifies the whole thing. One shot."),
                Lesson(title: "Fading out gracefully", body: "Ghosting is weak. A simple 'hey I don't think we're a match but enjoyed chatting — good luck out there' is rare and actually respected."),
                Lesson(title: "When they're hot and cold", body: "Inconsistent attention is often anxiety, not manipulation. But the effect on you is the same. Decide whether you can handle the pattern — not whether it's intentional.")
            ])
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { withAnimation { category = nil }; if category == nil { onBack() } }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundColor(.rwTextPrimary)
                        .frame(width: 36, height: 36).background(Color.rwSurface).clipShape(Circle())
                }
                Spacer()
                Text(category?.title ?? "Lessons").font(RWF.head()).foregroundColor(.rwTextPrimary)
                Spacer()
                Spacer().frame(width: 36)
            }
            .padding(.horizontal, SP.lg).padding(.vertical, 14)
            RWLine()

            if let cat = category {
                LessonDetailView(category: cat) { withAnimation { category = nil } }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(categories) { cat in
                            Button { withAnimation { category = cat } } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white).frame(width: 52, height: 52)
                                        .background(cat.color).clipShape(RoundedRectangle(cornerRadius: RR.md))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cat.title).font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                                        Text("\(cat.lessons.count) lessons").font(RWF.cap()).foregroundColor(.rwTextSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
                                }
                                .padding(SP.md).background(Color.rwCard)
                                .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                                .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
                                .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
                            }
                            .buttonStyle(SBS())
                        }
                        Spacer().frame(height: 80)
                    }
                    .padding(.horizontal, SP.lg).padding(.top, 16)
                }
                .rwBG()
            }
        }
        .rwBG()
    }
}

struct LessonCategory: Identifiable {
    let id = UUID(); let title: String; let icon: String; let color: Color; let lessons: [Lesson]
}

struct Lesson: Identifiable {
    let id = UUID(); let title: String; let body: String
}

struct LessonDetailView: View {
    let category: LessonCategory; let onBack: () -> Void
    @State private var current = 0

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<category.lessons.count, id: \.self) { i in
                    Circle().fill(i == current ? category.color : Color.rwBorder)
                        .frame(width: i == current ? 10 : 7, height: i == current ? 10 : 7)
                        .animation(.spring(response: 0.3), value: current)
                }
            }
            .padding(.vertical, 16)

            Spacer()

            // Card
            VStack(alignment: .leading, spacing: SP.lg) {
                Image(systemName: category.icon)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundColor(category.color)
                    .frame(width: 64, height: 64)
                    .background(category.color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: RR.lg))

                Text(category.lessons[current].title)
                    .font(RWF.title(24)).foregroundColor(.rwTextPrimary)

                Text(category.lessons[current].body)
                    .font(RWF.body(17)).foregroundColor(.rwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .padding(SP.xl).background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xxl))
            .overlay(RoundedRectangle(cornerRadius: RR.xxl).stroke(Color.rwBorder, lineWidth: 1))
            .shadow(color: Color.rwShadow, radius: 20, x: 0, y: 6)
            .padding(.horizontal, SP.lg)

            Spacer()

            // Navigation
            HStack(spacing: 12) {
                if current > 0 {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { current -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundColor(.rwTextPrimary)
                            .frame(maxWidth: .infinity).padding(.vertical, 17)
                            .background(Color.rwSurface)
                            .clipShape(RoundedRectangle(cornerRadius: RR.pill))
                    }
                    .buttonStyle(SBS())
                }

                Button {
                    if current < category.lessons.count - 1 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { current += 1 }
                    } else {
                        onBack()
                    }
                } label: {
                    Text(current < category.lessons.count - 1 ? "Next" : "Done")
                        .font(RWF.med()).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 17)
                        .background(LinearGradient.accent)
                        .clipShape(RoundedRectangle(cornerRadius: RR.pill))
                        .shadow(color: Color(hex: "E8356D").opacity(0.3), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(SBS())
            }
            .padding(.horizontal, SP.lg).padding(.bottom, 44)
        }
        .rwBG()
    }
}

// MARK: - Game / Challenge Mode

struct GameView: View {
    let onBack: () -> Void
    @State private var challenge: Challenge? = nil
    @State private var userAnswer = ""
    @State private var score: GameScore? = nil
    @State private var isLoading = false
    @State private var timeLeft = 60
    @State private var timerActive = false
    @State private var timer: Timer? = nil
    @FocusState private var focused: Bool

    let challenges: [Challenge] = [
        Challenge(id: "1", title: "Best Opener", prompt: "Write the best opening message for someone whose bio says:\n\n\"Pediatric nurse, marathon runner, obsessed with true crime podcasts. Will judge you for your coffee order (lovingly).\"", timeLimit: 60),
        Challenge(id: "2", title: "Save a Dying Convo", prompt: "They replied 'haha yeah' to your last message. Write one message that revives this conversation.", timeLimit: 45),
        Challenge(id: "3", title: "Ask for the Number", prompt: "You've been talking for 4 days. Write a message that naturally asks for their number without it feeling abrupt.", timeLimit: 60),
        Challenge(id: "4", title: "Respond to Ghosting", prompt: "They haven't responded in 5 days. You want to reach out one more time. Write it.", timeLimit: 45),
        Challenge(id: "5", title: "Suggest a Date", prompt: "Great conversation. Write a message suggesting your first date — specific time, place, and vibe.", timeLimit: 60)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { stopTimer(); onBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundColor(.rwTextPrimary)
                        .frame(width: 36, height: 36).background(Color.rwSurface).clipShape(Circle())
                }
                Spacer()
                Text("Challenge Mode").font(RWF.head()).foregroundColor(.rwTextPrimary)
                Spacer()
                Spacer().frame(width: 36)
            }
            .padding(.horizontal, SP.lg).padding(.vertical, 14)
            RWLine()

            if let result = score {
                // Result view
                ScrollView(showsIndicators: false) {
                    VStack(spacing: SP.lg) {
                        VStack(spacing: 8) {
                            Text("\(result.score)/10")
                                .font(.system(size: 72, weight: .black, design: .rounded))
                                .foregroundStyle(LinearGradient.accent)
                            Text(result.grade).font(RWF.title()).foregroundColor(.rwTextPrimary)
                        }
                        .padding(.top, 32)

                        RWCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Cyrano's take", systemImage: "bubble.left.fill")
                                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                                Text(result.feedback).font(RWF.body()).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        RWCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Your message", systemImage: "text.quote")
                                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                                Text(userAnswer).font(RWF.body()).foregroundColor(.rwTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        RWButton("Try Another Challenge") {
                            withAnimation { challenge = nil; score = nil; userAnswer = "" }
                        }
                        .padding(.bottom, 48)
                    }
                    .padding(.horizontal, SP.lg)
                }
                .rwBG()

            } else if let c = challenge {
                // Active challenge
                VStack(spacing: 0) {
                    // Timer
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "timer").font(.system(size: 14, weight: .semibold, design: .rounded))
                            Text("\(timeLeft)s").font(RWF.head())
                        }
                        .foregroundColor(timeLeft <= 10 ? .rwAccent : .rwTextSecondary)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(timeLeft <= 10 ? Color.rwAccent.opacity(0.1) : Color.rwSurface)
                        .clipShape(Capsule())
                        Spacer()
                    }
                    .padding(.horizontal, SP.lg).padding(.vertical, 12)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: SP.lg) {
                            Text(c.title).font(RWF.title()).foregroundColor(.rwTextPrimary)
                            Text(c.prompt).font(RWF.body()).foregroundColor(.rwTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(SP.md).background(Color.rwSurface)
                                .clipShape(RoundedRectangle(cornerRadius: RR.lg))

                            ZStack(alignment: .topLeading) {
                                if userAnswer.isEmpty {
                                    Text("Write your message here...")
                                        .font(RWF.body()).foregroundColor(.rwTextMuted)
                                        .padding(.horizontal, 4).padding(.vertical, 12).allowsHitTesting(false)
                                }
                                TextEditor(text: $userAnswer)
                                    .font(RWF.body()).foregroundColor(.rwTextPrimary)
                                    .frame(minHeight: 120).scrollContentBackground(.hidden).focused($focused)
                            }
                            .padding(SP.md).background(Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                            .overlay(RoundedRectangle(cornerRadius: RR.lg)
                                .stroke(focused ? Color.rwAccent.opacity(0.3) : Color.rwBorder, lineWidth: 1))
                            .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)

                            Spacer().frame(height: 80)
                        }
                        .padding(.horizontal, SP.lg)
                    }

                    RWLine()
                    RWButton(isLoading ? "Scoring..." : "Submit for Score", icon: isLoading ? nil : "bolt.fill") {
                        focused = false; stopTimer()
                        Task { await scoreMessage(c) }
                    }
                    .disabled(userAnswer.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    .opacity(userAnswer.isEmpty ? 0.5 : 1)
                    .padding(.horizontal, SP.lg).padding(.vertical, 14)
                }
                .rwBG()
                .onAppear { startTimer(limit: c.timeLimit) }

            } else {
                // Challenge picker
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        Text("Pick a challenge").font(RWF.head())
                            .foregroundColor(.rwTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        ForEach(challenges) { c in
                            Button {
                                withAnimation { challenge = c; userAnswer = ""; timeLeft = c.timeLimit; score = nil }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focused = true }
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(c.title).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                                        Text("\(c.timeLimit)s time limit").font(RWF.cap()).foregroundColor(.rwTextSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "bolt.fill").foregroundColor(.rwGold)
                                    Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
                                }
                                .padding(SP.md).background(Color.rwCard)
                                .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                                .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
                                .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
                            }
                            .buttonStyle(SBS())
                        }
                        Spacer().frame(height: 80)
                    }
                    .padding(.horizontal, SP.lg).padding(.top, 16)
                }
                .rwBG()
            }
        }
        .rwBG()
    }

    func startTimer(limit: Int) {
        timeLeft = limit; timerActive = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            if timeLeft > 0 { timeLeft -= 1 }
            else { t.invalidate(); timerActive = false }
        }
    }

    func stopTimer() { timer?.invalidate(); timer = nil; timerActive = false }

    func scoreMessage(_ c: Challenge) async {
        isLoading = true
        let system = """
        You are Cyrano, a dating conversation coach. Score this message out of 10 and give direct feedback.
        Challenge: \(c.title)
        Prompt: \(c.prompt)
        
        Return a score from 1-10, a one-word grade (Excellent/Great/Good/Average/Weak), and 2-3 sentences of specific feedback.
        Format exactly:
        SCORE: [number]
        GRADE: [word]
        FEEDBACK: [2-3 sentences]
        """
        do {
            let raw = try await Claude.shared.send(system: system, user: "Message: \"\(userAnswer)\"", max: 300)
            let lines = raw.components(separatedBy: "\n")
            var s = 7; var g = "Good"; var fb = raw
            for line in lines {
                if line.hasPrefix("SCORE:") { s = Int(line.replacingOccurrences(of: "SCORE:", with: "").trimmingCharacters(in: .whitespaces)) ?? 7 }
                if line.hasPrefix("GRADE:") { g = line.replacingOccurrences(of: "GRADE:", with: "").trimmingCharacters(in: .whitespaces) }
                if line.hasPrefix("FEEDBACK:") { fb = line.replacingOccurrences(of: "FEEDBACK:", with: "").trimmingCharacters(in: .whitespaces) }
            }
            await MainActor.run { score = GameScore(score: s, grade: g, feedback: fb) }
        } catch { await MainActor.run { score = GameScore(score: 0, grade: "Error", feedback: "Couldn't score. Try again.") } }
        isLoading = false
    }
}

struct Challenge: Identifiable {
    let id: String; let title: String; let prompt: String; let timeLimit: Int
}

struct GameScore {
    let score: Int; let grade: String; let feedback: String
}
