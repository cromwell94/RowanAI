import SwiftUI

// MARK: - Communication Lab Main

struct CommunicationLabView: View {
    @State private var mode: LabMode = .menu
    @State private var store = StoreManager.shared
    @State private var on = false

    enum LabMode { case menu, lessons, simulator }

    var body: some View {
        switch mode {
        case .menu:      menuView
        case .lessons:   LabLessonsView { mode = .menu }
        case .simulator: LabSimulatorView { mode = .menu }
        }
    }

    var menuView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Communication\nLab").font(RWF.display(30)).foregroundColor(.rwTextPrimary)
                    Text("Learn what actually makes conversations connect — then practice it safely before it counts.")
                        .font(RWF.body()).foregroundColor(.rwTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .staggerAppear(0, appeared: on)

                // Free taste banner
                if !store.isPro {
                    HStack(spacing: 10) {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(LinearGradient.accent)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Free preview included").font(RWF.head(13)).foregroundColor(.rwTextPrimary)
                            Text("3 lessons and 1 simulator session — no Pro needed.")
                                .font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                        }
                        Spacer()
                    }
                    .padding(SP.md).background(Color.rwAccent.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                    .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwAccent.opacity(0.15), lineWidth: 1))
                    .staggerAppear(1, appeared: on)
                }

                // Feature cards
                VStack(spacing: 14) {
                    LabFeatureCard(
                        icon: "book.fill",
                        title: "The 10 Lessons",
                        description: "Real communication patterns — what kills connection and what builds it. Short, honest, practical.",
                        color: Color(hex: "5B8DEF"),
                        tag: store.isPro ? "All 10 Unlocked" : "3 Free · 7 Pro",
                        tagColor: store.isPro ? Color(hex: "00BFB3") : Color(hex: "E8356D")
                    ) { withAnimation { mode = .lessons } }

                    LabFeatureCard(
                        icon: "message.fill",
                        title: "Text Simulator",
                        description: "Practice real conversations in a fake iMessage interface. Cyrano plays the other person and coaches you after every message.",
                        color: Color(hex: "E8356D"),
                        tag: store.isPro ? "All Scenarios" : "1 Free Session",
                        tagColor: store.isPro ? Color(hex: "00BFB3") : Color(hex: "E8356D")
                    ) { withAnimation { mode = .simulator } }
                }
                .staggerAppear(2, appeared: on)

                // What you'll learn
                RWCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What you'll learn").font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                        ForEach([
                            "Why asking questions without sharing yourself kills connection",
                            "How to listen instead of immediately solving",
                            "The difference between vulnerability and oversharing",
                            "How to read when someone is losing interest",
                            "When and how to move from texting to meeting",
                            "What makes a conversation feel effortless"
                        ], id: \.self) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13)).foregroundColor(Color(hex: "00BFB3"))
                                    .padding(.top, 1)
                                Text(item).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .opacity(on ? 1 : 0)

                if !store.isPro {
                    ProNudge()
                        .opacity(on ? 1 : 0)
                }

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg).padding(.top, 16)
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { on = true } }
    }
}

struct LabFeatureCard: View {
    let icon: String; let title: String; let description: String
    let color: Color; let tag: String; let tagColor: Color; let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                    .frame(width: 52, height: 52).background(color)
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title).font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                        Text(tag).font(RWF.micro()).foregroundColor(tagColor)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(tagColor.opacity(0.1)).clipShape(Capsule())
                    }
                    Text(description).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundColor(.rwTextMuted).padding(.top, 16)
            }
            .padding(SP.lg).background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
            .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Lessons

struct LabLessonsView: View {
    let onBack: () -> Void
    @State private var store = StoreManager.shared
    @State private var selected: LabLesson? = nil
    @State private var showPaywall = false

    let lessons: [LabLesson] = [
        LabLesson(
            number: 1, isFree: true,
            title: "The Interview Pattern",
            subtitle: "Why asking questions without sharing yourself kills connection",
            icon: "questionmark.bubble.fill",
            color: Color(hex: "5B8DEF"),
            scenario: """
Alex matched with someone they really liked. The conversation started strong:

Alex: "What do you do for fun?"
Match: "I love hiking and I'm obsessed with cooking. You?"
Alex: "Nice! Where do you like to hike?"
Match: "Mostly local trails. Do you hike?"
Alex: "Sometimes. What kind of food do you cook?"
Match: "Italian mostly. Do you cook?"
Alex: "Not really lol. What's your favourite restaurant?"

Three messages later — left on read.
""",
            whatWentWrong: "Every message was a question. Alex shared nothing. By message four, the match was doing all the work — answering, asking back, getting nothing in return. It felt like a job interview, not a conversation between two people.",
            thePrinciple: "Conversation is reciprocal. Every time you ask something, share something back. Not an essay — a sentence. 'I love hiking too — I did my first solo trail last month and nearly got lost, which was terrifying and kind of great.' Now there's something to respond to.",
            theFix: "After asking a question, add something about yourself. It doesn't have to be long. It just has to be real. You're not interrogating them — you're in a conversation together.",
            tryThis: "In your next conversation, after every question you ask — add one sentence about yourself related to the topic. Just one. Watch how differently it lands."
        ),
        LabLesson(
            number: 2, isFree: true,
            title: "Solving vs Listening",
            subtitle: "The difference that changes everything",
            icon: "ear.fill",
            color: Color(hex: "E8356D"),
            scenario: """
Jordan's match sent: "Ugh I had the worst day. My boss basically blamed me for a project that wasn't even my responsibility and I had to sit there and take it."

Jordan replied: "That's so unfair. You should document everything and talk to HR. Also make sure you CC your manager on emails going forward so there's a paper trail."

Match: "...yeah maybe"

And then nothing.
""",
            whatWentWrong: "Jordan immediately went into fix-it mode. The match didn't ask for advice — they wanted to feel heard. Jordan's response, however well-intentioned, communicated: 'I hear a problem. Here's the solution. Moving on.' It skipped the human part entirely.",
            thePrinciple: "When someone shares something hard, they almost always want acknowledgement before advice — and often instead of advice. The instinct to fix is well-meaning but it short-circuits connection. Feeling understood is what creates closeness. Solutions can come later, if they're asked for.",
            theFix: "Before offering any advice, reflect back what you heard. 'That sounds genuinely awful — being blamed for something that wasn't yours and having to just sit with it. That's a really frustrating position to be in.' Then wait. Let them respond. If they want advice, they'll ask.",
            tryThis: "Next time someone shares something difficult, respond only with acknowledgement. No advice unless they ask. Notice how the conversation changes."
        ),
        LabLesson(
            number: 3, isFree: true,
            title: "Specificity Over Flattery",
            subtitle: "Why 'you're so interesting' lands worse than you think",
            icon: "star.fill",
            color: Color(hex: "F59E0B"),
            scenario: "A generic opener vs a specific one — and why one gets replies and one doesn't.",
            whatWentWrong: "Generic compliments signal you didn't pay attention.",
            thePrinciple: "Specificity shows you actually looked. It's the difference between 'you seem cool' and 'the fact that you learned to surf at 30 — that takes real nerve. What made you decide to start?'",
            theFix: "Reference something specific from their profile or what they said. Make it clear you were actually paying attention.",
            tryThis: "Write your next opener using only something specific from their profile. No compliments about appearance. No 'hey.' Something that could only be sent to them."
        ),
        LabLesson(
            number: 4, isFree: false,
            title: "Energy Matching",
            subtitle: "Reading the room in text form",
            icon: "waveform",
            color: Color(hex: "9B59B6"),
            scenario: "Someone sends three enthusiastic paragraphs. You reply with 'haha yeah cool.' What just happened.",
            whatWentWrong: "A massive mismatch in investment. They opened up — you didn't meet them there.",
            thePrinciple: "Match the energy someone brings. Not word-for-word — but in spirit. If they're enthusiastic and engaged, bring that back. If they're brief, be brief. Energy matching signals mutual investment.",
            theFix: "Before you reply, notice the length and tone of what they sent. Match it approximately. Not exactly — but don't send two words to three paragraphs.",
            tryThis: "For one week, consciously match the energy of every message you receive. Notice whether responses change."
        ),
        LabLesson(
            number: 5, isFree: false,
            title: "The Art of the Callback",
            subtitle: "The most underrated conversation move",
            icon: "arrow.counterclockwise",
            color: Color(hex: "00BFB3"),
            scenario: "Three days into a conversation, bringing back something small they mentioned on day one — and watching what happens.",
            whatWentWrong: "Most people never do this. Every message exists in isolation.",
            thePrinciple: "Referencing something someone said earlier — even casually — signals that you were actually listening and that they stayed with you. It creates a sense of shared history even early in a connection.",
            theFix: "When someone mentions something — their dog's name, a trip they're planning, a bad day at work — file it away. Bring it back naturally later. 'How did that presentation go by the way?'",
            tryThis: "In your next conversation, reference something they mentioned in a previous message. Watch their reaction."
        ),
        LabLesson(
            number: 6, isFree: false,
            title: "Vulnerability Without Oversharing",
            subtitle: "How to let someone in without flooding them",
            icon: "lock.open.fill",
            color: Color(hex: "E8356D"),
            scenario: "The difference between 'I'm an open book' and actually being open — and why one creates connection and one creates distance.",
            whatWentWrong: "Sharing too much too fast creates discomfort. Sharing nothing creates distance. The calibration matters.",
            thePrinciple: "Vulnerability is earned gradually. Share something real — a genuine opinion, a small failure, something that matters to you — but let it be proportional to the trust you've built. A sentence, not a monologue.",
            theFix: "Match your depth of sharing to where you actually are in the connection. Early on: opinions, preferences, small stories. Later: real fears, real history.",
            tryThis: "Share one genuine opinion in your next conversation. Not a fact — an actual view you hold on something."
        ),
        LabLesson(
            number: 7, isFree: false,
            title: "Reading Disengagement",
            subtitle: "When to give space vs when to reach out",
            icon: "thermometer.snowflake",
            color: Color(hex: "5B8DEF"),
            scenario: "Responses went from paragraphs to one word. You send another message. Then another. Then 'you okay?'",
            whatWentWrong: "Doubling down on disengagement usually accelerates it. The instinct to fix the silence often makes it worse.",
            thePrinciple: "Disengagement signals need space, not more input. One message, then wait. If they want to re-engage, they will. If they don't, more messages won't change that — they'll just confirm you don't read the room.",
            theFix: "When energy drops: send one light message — not a check-in, not 'you okay', just something easy and low-pressure. Then stop. Let it breathe.",
            tryThis: "The next time a conversation goes quiet, send one message and leave it. Don't follow up until they respond."
        ),
        LabLesson(
            number: 8, isFree: false,
            title: "Knowing When to Move",
            subtitle: "The window — how to see it and how to step through it",
            icon: "calendar.badge.plus",
            color: Color(hex: "00BFB3"),
            scenario: "Great conversation. Two weeks in. Still no date. The momentum is starting to die.",
            whatWentWrong: "Waiting too long is just as damaging as moving too fast. Connections have a natural window. Miss it and you end up as pen pals.",
            thePrinciple: "The window opens when conversation is warm, consistent, and mutual. Usually within 5-7 days of good back-and-forth. Specific is better than vague — 'free Thursday?' converts better than 'we should hang sometime.'",
            theFix: "When conversation feels good, that's the moment. Name a specific day and a specific idea. Confidence and specificity signal that you're worth meeting.",
            tryThis: "Identify one conversation where you've been talking for more than a week. If it's warm — suggest something specific this week."
        ),
        LabLesson(
            number: 9, isFree: false,
            title: "Intensity Before Trust",
            subtitle: "Why coming on strong early usually backfires",
            icon: "flame.fill",
            color: Color(hex: "F59E0B"),
            scenario: "Day two of talking. 'I feel like I've known you forever. You're different from everyone else.'",
            whatWentWrong: "Intense feelings expressed before any real trust exists feel destabilising, not romantic. It signals a lack of self-awareness and puts pressure on the other person to either match an intensity they haven't built or back away.",
            thePrinciple: "Attraction builds through calibrated revelation over time. Mystery matters early. Let connection develop at its own pace — forcing it communicates insecurity, not depth.",
            theFix: "Match your emotional investment to where you actually are in the connection. Early on: warm but not overwhelming. Let them come toward you.",
            tryThis: "Notice if you have a habit of expressing strong feelings early. In your next connection, let it develop one step at a time."
        ),
        LabLesson(
            number: 10, isFree: false,
            title: "The Reassurance Trap",
            subtitle: "What double-texting and 'you okay?' actually communicates",
            icon: "exclamationmark.bubble.fill",
            color: Color(hex: "E8356D"),
            scenario: "They took six hours to reply. You sent a follow-up after two. Then 'did I say something wrong?' after four.",
            whatWentWrong: "Each follow-up communicated anxiety and a need for reassurance. Which is understandable — but it puts the other person in the position of managing your feelings instead of simply enjoying the connection.",
            thePrinciple: "Self-regulation is attractive. Being able to sit with uncertainty — to not need constant confirmation that things are okay — signals security. Security is one of the most attractive qualities a person can have.",
            theFix: "Send one message. If they don't respond — they're busy, or they need space, or they're not interested. None of those outcomes are changed by a follow-up. Wait for a response before sending another.",
            tryThis: "For two weeks: one message at a time. No follow-ups until you get a reply. Notice how it changes your anxiety levels and the responses you get."
        ),
        LabLesson(
            number: 11, isFree: false,
            title: "Flirting Without Being Creepy",
            subtitle: "The line between charming and uncomfortable",
            icon: "sparkles",
            color: Color(hex: "E8356D"),
            scenario: """
Sam sent: "You look incredible in every photo. I keep coming back to look at them. You're honestly the most attractive person I've matched with in months."

No reply.
""",
            whatWentWrong: "This reads as intensity without connection. Focusing entirely on appearance — especially with 'I keep coming back to look at them' — feels more like fixation than genuine interest. It puts all the weight on looks and none on who she actually is.",
            thePrinciple: "Flirting works when it's light, specific, and mutual. It's a tone, not a statement. The best flirting feels playful and slightly surprising — it makes someone smile, not feel studied. It works alongside genuine curiosity about them as a person.",
            theFix: "Flirt with wit, not intensity. Reference something specific about them beyond appearance. Keep it light — one playful line lands better than three earnest compliments. Leave room for them to play back.",
            tryThis: "Write a message that makes someone smile without mentioning how they look. Use something from their profile or something they said. Playful and specific beats sincere and generic every time."
        ),
        LabLesson(
            number: 12, isFree: false,
            title: "Handling Rejection Gracefully",
            subtitle: "What you do after no is more revealing than anything else",
            icon: "hand.raised.fill",
            color: Color(hex: "5B8DEF"),
            scenario: """
Alex asked someone out. They replied: "Thanks so much, you seem genuinely lovely — I just don't feel a romantic connection. I hope you find someone great."

Alex replied: "Wow okay. Didn't realise I was that bad. Good luck I guess."
""",
            whatWentWrong: "Alex made the rejection about ego instead of grace. The response communicated bitterness and put the other person in the position of feeling bad for being honest. It also revealed that the warmth Alex showed before was conditional on getting what he wanted.",
            thePrinciple: "How you handle a no says everything about your character. Someone who rejects you kindly deserves a kind response. Grace under rejection is rare — and people notice it. It also protects your own dignity far better than any sharp comeback.",
            theFix: "A simple, warm response closes the loop cleanly. 'Thanks for being honest — I appreciate that. Take care.' That's it. Nothing to defend, nothing to attack. You leave as the person who handled it well.",
            tryThis: "Think about the last time you faced rejection. How did you respond? What would the graceful version have looked like? Write it out — not to send, just to practice the mindset."
        ),
        LabLesson(
            number: 13, isFree: false,
            title: "Texting Cadence",
            subtitle: "Timing matters more than most people think",
            icon: "clock.fill",
            color: Color(hex: "F59E0B"),
            scenario: """
Jordan matched with someone on Sunday. By Tuesday they had texted 47 times — asking questions, sharing stories, sending memes. The match replied less and less. By Thursday: silence.
""",
            whatWentWrong: "47 texts in two days creates a pressure no early connection can hold. It signals that the person has made this match the centre of their attention — before any real relationship exists to justify that intensity. It removes all mystery and makes the relationship feel like work before it's begun.",
            thePrinciple: "Early on, less is more. Conversations should have natural rhythms — not a constant stream. Allowing gaps creates anticipation. You want them to look forward to hearing from you, not feel like they're behind on a task.",
            theFix: "Match their cadence and leave space. If they reply every few hours, do the same. If a conversation has a natural ending, let it end. The next one will be better for it.",
            tryThis: "For your next match, allow at least one natural conversation ending before starting a new thread. Notice whether the next conversation feels more energised."
        ),
        LabLesson(
            number: 14, isFree: false,
            title: "The Art of the Pause",
            subtitle: "Letting silence do the work",
            icon: "pause.circle.fill",
            color: Color(hex: "9B59B6"),
            scenario: """
Every time there was a lull in the conversation, Morgan immediately sent something new — a question, a meme, a random observation. The conversation never had a moment to breathe.
""",
            whatWentWrong: "Filling every silence communicates anxiety. It signals that you need the conversation to keep going — which puts pressure on the other person and removes any sense of mystery or ease. Real connection has rhythm, not a constant stream.",
            thePrinciple: "Silence in a conversation is not a problem to solve. Sometimes a conversation has a natural ending and that is fine. Some of the best interactions end before they run out of steam — leaving both people wanting more.",
            theFix: "When a conversation naturally winds down, let it. Don't manufacture a reason to keep it going. Start a new thread later with something fresh and specific. Absence creates interest.",
            tryThis: "Let a conversation end naturally this week. Don't send the follow-up message. Notice how different the next conversation feels."
        ),
        LabLesson(
            number: 15, isFree: false,
            title: "Cultural Awareness in Dating",
            subtitle: "Connection across different backgrounds",
            icon: "globe",
            color: Color(hex: "00BFB3"),
            scenario: """
Chris matched with someone from a different cultural background. He made jokes about their culture early on — harmless in his mind. She didn't reply again.
""",
            whatWentWrong: "Joking about someone's culture early signals that you see their background as a novelty rather than an integral part of who they are. Even well-intentioned humour can land as reductive when trust hasn't been established.",
            thePrinciple: "Cultural curiosity is attractive. Cultural assumptions are not. There's a significant difference between 'I'd love to understand more about your background' and making assumptions or jokes based on stereotypes. Genuine curiosity — asking open questions and actually listening — builds real connection across differences.",
            theFix: "Lead with curiosity, not assumptions. Ask genuine questions about their experience and actually listen. Share your own background openly. Find the human common ground before exploring the differences.",
            tryThis: "In your next cross-cultural conversation, ask one genuine question about their experience — not about their culture as a category, but about their personal relationship to it."
        ),
        LabLesson(
            number: 16, isFree: false,
            title: "Humour as a Tool",
            subtitle: "Why some jokes connect and some disconnect",
            icon: "face.smiling.fill",
            color: Color(hex: "F59E0B"),
            scenario: """
"I'm not like other guys on here 😂" — sent as an opener by someone who thought self-deprecating humour would make them stand out.

They got a polite non-reply.
""",
            whatWentWrong: "Self-deprecation as an opener puts the other person in a strange position — do they agree? Disagree? Reassure? It also signals low confidence while trying to appear aware. And the 'not like other guys/girls' framing is so common it's become its own cliché.",
            thePrinciple: "Humour works best when it's specific, observational, and doesn't require the other person to manage your feelings. The best dating humour is light and creates a shared moment — not a performance for approval. Wit beats self-deprecation almost every time.",
            theFix: "Make the joke about something external — something you both observe. Or make it playful and specific to something in their profile. Avoid humour that requires them to reassure you or that makes your insecurity the subject.",
            tryThis: "Write a message that uses humour without any self-deprecation. Notice how it lands differently."
        ),
        LabLesson(
            number: 17, isFree: false,
            title: "When Things Get Heavy",
            subtitle: "How to handle deep topics early in a connection",
            icon: "cloud.heavyrain.fill",
            color: Color(hex: "5B8DEF"),
            scenario: """
Three days in, Jamie shared that they'd been through a difficult divorce and were struggling with it. Their match, not knowing what to say, replied: "Oh wow. Yeah breakups are tough. Anyway what did you do this weekend?"
""",
            whatWentWrong: "Pivoting immediately after someone shares something heavy communicates that you don't have the capacity to sit with difficult things. It's not malicious — but it leaves the person feeling unseen at a vulnerable moment.",
            thePrinciple: "You don't need to have the perfect response to heavy things. You just need to stay present. Acknowledging what someone shared — even briefly — before moving on shows that you can handle emotional depth. That is genuinely rare and genuinely attractive.",
            theFix: "Pause on the heavy thing before moving forward. 'That sounds like it's been a really hard time — I appreciate you sharing that with me' is enough. Then you can ask where they're at with it, or let them guide where the conversation goes.",
            tryThis: "Next time someone shares something difficult, respond only to that before asking anything else. Let them feel heard before moving forward."
        ),
        LabLesson(
            number: 18, isFree: false,
            title: "Moving From Text to Real Life",
            subtitle: "The art of the transition",
            icon: "figure.2.arms.open",
            color: Color(hex: "E8356D"),
            scenario: """
"We should hang out sometime" — sent after two weeks of great conversation.

They said "yeah definitely!" and then... nothing happened.
""",
            whatWentWrong: "Vague suggestions create vague momentum — which is no momentum at all. 'We should hang out' is not an invitation, it's an idea. Without specificity, it stays an idea forever.",
            thePrinciple: "The transition from text to real life requires specificity and confidence. A specific suggestion signals genuine interest and takes the decision-making burden off the other person. It also creates a moment — a real thing to either say yes or no to — rather than a hypothetical.",
            theFix: "Name a day, a general idea, and ask if it works. 'I know a good coffee place in [area] — free Saturday afternoon?' is a real invitation. It gives them something to respond to and signals that you actually want this to happen.",
            tryThis: "If there's a conversation that's been going well for more than a week — ask this week. Be specific. Day, rough idea, question. That's all it takes."
        ),
        LabLesson(
            number: 19, isFree: false,
            title: "After the First Date",
            subtitle: "What happens next matters",
            icon: "calendar.badge.checkmark",
            color: Color(hex: "00BFB3"),
            scenario: """
The first date went well. Really well. Jordan waited three days to follow up because they'd read that waiting makes you seem less desperate. By then, the other person had mentally moved on.
""",
            whatWentWrong: "The 'waiting game' is a relic from an era when seeming unbothered was the goal. What it actually communicates is either disinterest or anxiety about appearing interested — neither of which builds connection.",
            thePrinciple: "If you had a good time, say so — within 24 hours. A genuine, warm follow-up message after a good date is one of the simplest and most effective things you can do. It closes the loop on the date and opens the door to the next one.",
            theFix: "Send a short, genuine message within 24 hours. Reference one specific moment from the date. Say you'd like to do it again if you would. That's it. No games. No strategy. Just honesty.",
            tryThis: "After your next date — good or bad — send a follow-up within 24 hours. If it was good: reference a specific moment and say you'd like to do it again. If it wasn't: a kind close is better than silence."
        ),
        LabLesson(
            number: 20, isFree: false,
            title: "Becoming Someone Worth Knowing",
            subtitle: "The conversation skill that comes before all the others",
            icon: "person.fill.checkmark",
            color: Color(hex: "E8356D"),
            scenario: """
Two people matched. One spent their evening crafting the perfect opener using formulas they'd read online. The other spent their evening doing something they loved, and opened with a genuine observation about something that happened that day.

Guess which conversation went further.
""",
            whatWentWrong: "The formula approach treats conversation as a performance to be optimised. But people can feel when they're being run through a technique — even if they can't articulate why. It creates a subtle disconnection.",
            thePrinciple: "The most attractive thing you can do for your dating life is have a rich inner one. People who are genuinely interested in things, who have opinions, who are building something, who laugh easily — these people are naturally compelling to talk to. Technique helps. Character is the foundation.",
            theFix: "Invest in yourself as much as you invest in your dating strategy. Read things. Do things. Form opinions. Be someone who has something to bring to the conversation — not because it's attractive, but because it's a good life.",
            tryThis: "This week: do one thing for no reason other than that it interests you. Talk about it openly with someone. Notice how differently you show up when you're engaged with your own life."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.rwTextPrimary).frame(width: 36, height: 36)
                        .background(Color.rwSurface).clipShape(Circle())
                }
                Spacer()
                Text("The 10 Lessons").font(RWF.head()).foregroundColor(.rwTextPrimary)
                Spacer()
                Spacer().frame(width: 36)
            }
            .padding(.horizontal, SP.lg).padding(.vertical, 14)
            RWLine()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    if !store.isPro {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill").font(.system(size: 11))
                            Text("Lessons 4-10 require Pro. Lessons 1-3 are free.")
                                .font(RWF.cap(12))
                        }
                        .foregroundColor(.rwTextMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    }

                    ForEach(lessons) { lesson in
                        if lesson.isFree || store.isPro {
                            Button { selected = lesson } label: { LessonRow(lesson: lesson, locked: false) }
                                .buttonStyle(SBS())
                        } else {
                            Button { showPaywall = true } label: { LessonRow(lesson: lesson, locked: true) }
                                .buttonStyle(SBS())
                        }
                    }

                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, SP.lg).padding(.top, 12)
            }
        }
        .rwBG()
        .sheet(isPresented: Binding(
            get: { selected != nil },
            set: { if !$0 { selected = nil } }
        )) {
            if let lesson = selected {
                LessonDetailView2(lesson: lesson)
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView(reason: .generic) }
    }
}

struct LessonRow: View {
    let lesson: LabLesson; let locked: Bool
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: RR.md)
                    .fill(locked ? Color.rwSurface : lesson.color)
                    .frame(width: 52, height: 52)
                if locked {
                    Image(systemName: "lock.fill").font(.system(size: 18)).foregroundColor(.rwTextMuted)
                } else {
                    Image(systemName: lesson.icon).font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Lesson \(lesson.number)").font(RWF.micro()).foregroundColor(.rwTextMuted)
                    if lesson.isFree {
                        Text("FREE").font(RWF.micro()).foregroundColor(Color(hex: "00BFB3"))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(hex: "00BFB3").opacity(0.1)).clipShape(Capsule())
                    }
                }
                Text(lesson.title).font(RWF.head(15)).foregroundColor(locked ? .rwTextMuted : .rwTextPrimary)
                Text(lesson.subtitle).font(RWF.body(12)).foregroundColor(.rwTextMuted).lineLimit(1)
            }
            Spacer()
            Image(systemName: locked ? "lock.fill" : "chevron.right")
                .font(.system(size: 13)).foregroundColor(.rwTextMuted)
        }
        .padding(SP.md).background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
        .shadow(color: Color.rwShadow, radius: 6, x: 0, y: 2)
        .opacity(locked ? 0.6 : 1)
    }
}

struct LessonDetailView2: View {
    let lesson: LabLesson
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SP.xl) {
                    // Header
                    HStack(spacing: 14) {
                        Image(systemName: lesson.icon)
                            .font(.system(size: 24, weight: .semibold)).foregroundColor(.white)
                            .frame(width: 60, height: 60).background(lesson.color)
                            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lesson \(lesson.number)").font(RWF.cap()).foregroundColor(.rwTextMuted)
                            Text(lesson.title).font(RWF.title(20)).foregroundColor(.rwTextPrimary)
                        }
                    }

                    // Scenario
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Real scenario", systemImage: "doc.text.fill")
                            .font(RWF.cap()).foregroundColor(.rwTextMuted)
                        Text(lesson.scenario).font(RWF.body(15)).foregroundColor(.rwTextSecondary)
                            .fixedSize(horizontal: false, vertical: true).lineSpacing(5)
                            .padding(SP.md).background(Color.rwSurface)
                            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                    }

                    // What went wrong
                    VStack(alignment: .leading, spacing: 8) {
                        Label("What went wrong", systemImage: "exclamationmark.triangle.fill")
                            .font(RWF.cap()).foregroundColor(Color(hex: "E8356D"))
                        Text(lesson.whatWentWrong).font(RWF.body()).foregroundColor(.rwTextPrimary)
                            .fixedSize(horizontal: false, vertical: true).lineSpacing(4)
                    }

                    RWLine()

                    // The principle
                    VStack(alignment: .leading, spacing: 8) {
                        Label("The principle", systemImage: "lightbulb.fill")
                            .font(RWF.cap()).foregroundColor(Color(hex: "F59E0B"))
                        Text(lesson.thePrinciple).font(RWF.body()).foregroundColor(.rwTextPrimary)
                            .fixedSize(horizontal: false, vertical: true).lineSpacing(4)
                    }

                    // The fix
                    VStack(alignment: .leading, spacing: 8) {
                        Label("The fix", systemImage: "checkmark.circle.fill")
                            .font(RWF.cap()).foregroundColor(Color(hex: "00BFB3"))
                        Text(lesson.theFix).font(RWF.body()).foregroundColor(.rwTextPrimary)
                            .fixedSize(horizontal: false, vertical: true).lineSpacing(4)
                    }

                    // Try this
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20)).foregroundColor(lesson.color)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Try this").font(RWF.head(14)).foregroundColor(.rwTextPrimary)
                            Text(lesson.tryThis).font(RWF.body(14)).foregroundColor(.rwTextSecondary)
                                .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
                        }
                    }
                    .padding(SP.md).background(lesson.color.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                    .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(lesson.color.opacity(0.2), lineWidth: 1))

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, SP.lg).padding(.top, 16)
            }
            .rwBG()
            .navigationTitle("Lesson \(lesson.number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.rwAccent)
                }
            }
        }
    }
}

struct LabLesson: Identifiable {
    let id = UUID()
    let number: Int; let isFree: Bool
    let title: String; let subtitle: String; let icon: String; let color: Color
    let scenario: String; let whatWentWrong: String; let thePrinciple: String
    let theFix: String; let tryThis: String
}

// MARK: - Text Simulator

struct LabSimulatorView: View {
    let onBack: () -> Void
    @State private var store = StoreManager.shared
    @State private var scenario: SimScenario? = nil
    @State private var messages: [SimMessage] = []
    @State private var input = ""
    @State private var isLoading = false
    @State private var coachCard: CoachCard? = nil
    @State private var showCoachCard = false
    @State private var exchangeCount = 0
    @State private var showFinalDebrief = false
    @State private var finalDebrief: FinalDebrief? = nil
    @State private var showPaywall = false
    @State private var sessionUsed = false
    @FocusState private var focused: Bool

    let freeMessageLimit = 6

    let scenarios: [SimScenario] = [
        SimScenario(id: "1", title: "The First Message", isFree: true,
            description: "You just matched. Their profile mentions they're a nurse who runs marathons and loves bad reality TV. Write your opener.",
            systemPrompt: """
            You are playing a dating app match named Alex. Your profile says you're a pediatric nurse who runs marathons and watches bad reality TV. You just matched with the user.
            Personality: warm but not immediately easy, genuine, slightly dry sense of humour. You respond like a real person — not overly enthusiastic, but engaged if the message earns it.
            Keep responses to 1-3 sentences like real texts.
            After each user message, you MUST also return a JSON coach card in this exact format on a new line:
            COACH:{"rating":"good|okay|weak","headline":"8 words max","insight":"1-2 sentences specific to what they said","tip":"one specific thing to do differently or keep doing"}
            """),
        SimScenario(id: "2", title: "Keeping Momentum", isFree: false,
            description: "You've been talking for 3 days. Things were great but the last few messages have gotten shorter. Turn it around.",
            systemPrompt: """
            You are a dating app match who was enthusiastic but has gotten a bit quieter over the last day or so. Not uninterested — just busy and giving shorter replies. You respond like a real person. Keep responses brief — 1-2 sentences.
            After each user message, return a coach card:
            COACH:{"rating":"good|okay|weak","headline":"8 words max","insight":"1-2 sentences","tip":"one specific thing"}
            """),
        SimScenario(id: "3", title: "After the Hard Day", isFree: false,
            description: "They texted: 'Ugh worst day. My boss is impossible and I'm exhausted.' Respond.",
            systemPrompt: """
            You are a dating app match who just had a genuinely rough day and vented briefly. You want to feel heard — not fixed. If the user immediately gives advice, you respond briefly and seem a bit deflated. If they acknowledge your feelings first, you open up more. Keep responses 1-3 sentences.
            After each user message, return a coach card:
            COACH:{"rating":"good|okay|weak","headline":"8 words max","insight":"1-2 sentences","tip":"one specific thing"}
            """),
        SimScenario(id: "4", title: "Asking Them Out", isFree: false,
            description: "Great week of conversation. Warm, mutual, fun. Now move it to a date without it feeling awkward.",
            systemPrompt: """
            You are a dating app match who has had a genuinely great week of conversation. You're interested. You're waiting to see if they'll suggest meeting — you won't bring it up first. If they ask you out confidently and specifically, say yes. If they're vague or over-explain, be a bit less enthusiastic. Keep responses 1-3 sentences.
            After each user message, return a coach card:
            COACH:{"rating":"good|okay|weak","headline":"8 words max","insight":"1-2 sentences","tip":"one specific thing"}
            """),
        SimScenario(id: "5", title: "Recovery", isFree: false,
            description: "You triple-texted yesterday. They read it but didn't reply. It's been 24 hours. One shot to recover.",
            systemPrompt: """
            You are a dating app match who received three messages in a row yesterday and felt a bit overwhelmed. You read them but didn't reply. You're not gone — just pulled back a little. If the user sends something light, non-desperate, and interesting, you'll re-engage. If they apologise excessively or ask 'you okay?' — you'll be polite but brief. Keep responses 1-3 sentences.
            After each user message, return a coach card:
            COACH:{"rating":"good|okay|weak","headline":"8 words max","insight":"1-2 sentences","tip":"one specific thing"}
            """)
    ]

    var isAtFreeLimit: Bool { !store.isPro && exchangeCount >= freeMessageLimit }
    var maxExchanges: Int { store.isPro ? 20 : freeMessageLimit }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    if scenario != nil { scenario = nil; messages = []; coachCard = nil; exchangeCount = 0; showFinalDebrief = false }
                    else { onBack() }
                }) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.rwTextPrimary).frame(width: 36, height: 36)
                        .background(Color.rwSurface).clipShape(Circle())
                }
                Spacer()
                Text(scenario?.title ?? "Text Simulator").font(RWF.head()).foregroundColor(.rwTextPrimary)
                Spacer()
                if scenario != nil {
                    Button("End") {
                        Task { await getFinalDebrief() }
                    }
                    .font(RWF.cap()).foregroundColor(.rwAccent)
                } else {
                    Spacer().frame(width: 36)
                }
            }
            .padding(.horizontal, SP.lg).padding(.vertical, 14)
            RWLine()

            if showFinalDebrief {
                finalDebriefView
            } else if let s = scenario {
                chatView(s)
            } else {
                scenarioPickerView
            }
        }
        .rwBG()
        .sheet(isPresented: $showPaywall) { PaywallView(reason: .practiceLimit) }
    }

    var scenarioPickerView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pick a scenario").font(RWF.title(22)).foregroundColor(.rwTextPrimary)
                    Text("Cyrano plays the other person. You practice. Get coached after every message.")
                        .font(RWF.body()).foregroundColor(.rwTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)

                if !store.isPro {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill").foregroundColor(Color(hex: "5B8DEF"))
                        Text("Scenario 1 is free. Go Pro to unlock all 5.")
                            .font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                    }
                    .padding(SP.sm)
                }

                ForEach(scenarios) { s in
                    Button {
                        if s.isFree || store.isPro {
                            if !s.isFree && sessionUsed {
                                showPaywall = true
                            } else {
                                scenario = s
                                messages = []
                                exchangeCount = 0
                                coachCard = nil
                                showFinalDebrief = false
                                finalDebrief = nil
                                if s.isFree { sessionUsed = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focused = true }
                            }
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: RR.md).fill(s.isFree || store.isPro ? Color(hex: "E8356D") : Color.rwSurface)
                                    .frame(width: 52, height: 52)
                                Image(systemName: s.isFree || store.isPro ? "message.fill" : "lock.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(s.isFree || store.isPro ? .white : .rwTextMuted)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    Text(s.title).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                                    if s.isFree {
                                        Text("FREE").font(RWF.micro()).foregroundColor(Color(hex: "00BFB3"))
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(Color(hex: "00BFB3").opacity(0.1)).clipShape(Capsule())
                                    }
                                }
                                Text(s.description).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: s.isFree || store.isPro ? "chevron.right" : "lock.fill")
                                .font(.system(size: 13)).foregroundColor(.rwTextMuted)
                        }
                        .padding(SP.md).background(Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
                        .shadow(color: Color.rwShadow, radius: 6, x: 0, y: 2)
                        .opacity((!s.isFree && !store.isPro) ? 0.6 : 1)
                    }
                    .buttonStyle(SBS())
                }
                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg).padding(.top, 12)
        }
    }

    func chatView(_ s: SimScenario) -> some View {
        VStack(spacing: 0) {
            // Scenario context
            Text(s.description).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, SP.lg).padding(.vertical, 12)
                .background(Color.rwSurface)

            // Coach card
            if let card = coachCard, showCoachCard {
                CoachCardView(card: card) { withAnimation { showCoachCard = false } }
                    .padding(.horizontal, SP.lg).padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Free limit warning
            if !store.isPro && exchangeCount >= freeMessageLimit - 1 {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill").font(.system(size: 11)).foregroundColor(.rwAccent)
                    Text(exchangeCount >= freeMessageLimit ?
                        "Free session complete — Go Pro to continue" :
                        "1 free message remaining")
                        .font(RWF.cap(12)).foregroundColor(.rwAccent)
                    Spacer()
                    if exchangeCount >= freeMessageLimit {
                        Button("Go Pro") { showPaywall = true }
                            .font(RWF.cap(12)).foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(LinearGradient.accent).clipShape(Capsule())
                    }
                }
                .padding(.horizontal, SP.lg).padding(.vertical, 8)
                .background(Color.rwAccent.opacity(0.08))
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        Spacer().frame(height: 8)
                        ForEach(messages) { msg in
                            SimMessageBubble(msg: msg)
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
                                .background(Color.rwSurface).clipShape(RoundedRectangle(cornerRadius: 18))
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

            // Input
            RWLine()
            if isAtFreeLimit {
                Button { showPaywall = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill").foregroundStyle(LinearGradient.accent)
                        Text("Go Pro to keep practicing").font(RWF.med()).foregroundColor(.rwTextPrimary)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
                    }
                    .padding(.horizontal, SP.lg).padding(.vertical, 16)
                }
                .buttonStyle(SBS())
                .background(Color.rwBackground)
            } else {
                HStack(spacing: 12) {
                    TextField("", text: $input, prompt: Text("Type your message...").foregroundColor(.rwTextMuted))
                        .font(RWF.body()).foregroundColor(.rwTextPrimary).focused($focused)
                        .onSubmit { Task { await send(scenario: s) } }
                    Button { Task { await send(scenario: s) } } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 30))
                            .foregroundColor(input.isEmpty ? .rwTextMuted : .rwAccent)
                    }
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isLoading).buttonStyle(SBS())
                }
                .padding(.horizontal, SP.lg).padding(.vertical, 14).background(Color.rwBackground)
            }
        }
    }

    var finalDebriefView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                if let debrief = finalDebrief {
                    VStack(spacing: 8) {
                        Text("\(debrief.score)/10")
                            .font(.system(size: 72, weight: .black, design: .rounded))
                            .foregroundStyle(LinearGradient.accent)
                        Text(debrief.grade).font(RWF.title(24)).foregroundColor(.rwTextPrimary)
                    }
                    .padding(.top, 24)

                    if store.isPro {
                        VStack(spacing: 14) {
                            DebriefSection(icon: "checkmark.circle.fill", title: "What worked", text: debrief.whatWorked, color: Color(hex: "00BFB3"))
                            DebriefSection(icon: "arrow.up.circle.fill", title: "What to improve", text: debrief.toImprove, color: Color(hex: "E8356D"))
                            DebriefSection(icon: "lightbulb.fill", title: "The one thing", text: debrief.oneThing, color: Color(hex: "F59E0B"))
                        }
                    } else {
                        RWCard {
                            VStack(spacing: 10) {
                                Text(debrief.whatWorked).font(RWF.body()).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                RWLine()
                                Button { showPaywall = true } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "lock.fill").foregroundStyle(LinearGradient.accent)
                                        Text("Go Pro for the full debrief").font(RWF.med(14)).foregroundColor(.rwTextPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
                                    }
                                }
                                .buttonStyle(SBS())
                            }
                        }
                    }

                    RWButton("Try Another Scenario") {
                        scenario = nil; messages = []; coachCard = nil
                        exchangeCount = 0; showFinalDebrief = false; finalDebrief = nil
                    }
                    .padding(.bottom, 48)
                } else {
                    RWLoading(msg: "Cyrano is reviewing your conversation...")
                        .frame(height: 200)
                }
            }
            .padding(.horizontal, SP.lg)
        }
        .sheet(isPresented: $showPaywall) { PaywallView(reason: .generic) }
    }

    func send(scenario s: SimScenario) async {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        messages.append(SimMessage(text: text, isUser: true))
        input = ""; isLoading = true; exchangeCount += 1

        let history = messages.map { "\($0.isUser ? "User" : "Alex"): \($0.text)" }.joined(separator: "\n")

        do {
            let raw = try await Claude.shared.send(
                system: s.systemPrompt,
                user: "Conversation:\n\(history)\n\nRespond as Alex, then on a new line return the COACH JSON.",
                max: 400)

            // Split response and coach card
            let parts = raw.components(separatedBy: "\nCOACH:")
            let reply = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            messages.append(SimMessage(text: reply, isUser: false))

            if parts.count > 1, let data = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
               let card = try? JSONDecoder().decode(CoachCard.self, from: data) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    coachCard = card
                    showCoachCard = true
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } catch {
            messages.append(SimMessage(text: "Something went wrong. Try again.", isUser: false))
        }
        isLoading = false
    }

    func getFinalDebrief() async {
        showFinalDebrief = true
        let history = messages.map { "\($0.isUser ? "You" : "Match"): \($0.text)" }.joined(separator: "\n")
        let system = """
        You are Cyrano reviewing a practice conversation. Give honest, specific feedback.
        Score out of 10. Return ONLY JSON:
        {"score":7,"grade":"Good Connection","whatWorked":"...","toImprove":"...","oneThing":"..."}
        """
        do {
            let raw = try await Claude.shared.send(system: system, user: "Conversation:\n\(history)", max: 300)
            let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = cleaned.data(using: .utf8),
               let debrief = try? JSONDecoder().decode(FinalDebrief.self, from: data) {
                await MainActor.run { finalDebrief = debrief }
            }
        } catch {}
    }
}

// MARK: - Supporting Types

struct SimScenario: Identifiable {
    let id: String; let title: String; let isFree: Bool
    let description: String; let systemPrompt: String
}

struct SimMessage: Identifiable {
    let id = UUID(); let text: String; let isUser: Bool
}

struct CoachCard: Codable, Identifiable {
    let id = UUID()
    let rating: String; let headline: String; let insight: String; let tip: String
    enum CodingKeys: String, CodingKey { case rating, headline, insight, tip }

    var ratingColor: Color {
        switch rating {
        case "good": return Color(hex: "00BFB3")
        case "okay": return Color(hex: "F59E0B")
        default:     return Color(hex: "E8356D")
        }
    }
    var ratingIcon: String {
        switch rating {
        case "good": return "checkmark.circle.fill"
        case "okay": return "minus.circle.fill"
        default:     return "exclamationmark.circle.fill"
        }
    }
}

struct FinalDebrief: Codable {
    let score: Int; let grade: String
    let whatWorked: String; let toImprove: String; let oneThing: String
}

// MARK: - UI Components

struct SimMessageBubble: View {
    let msg: SimMessage
    var body: some View {
        HStack {
            if msg.isUser { Spacer(minLength: 60) }
            Text(msg.text).font(RWF.body())
                .foregroundColor(msg.isUser ? .white : .rwTextPrimary)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(msg.isUser ? Color.rwAccent : Color.rwSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            if !msg.isUser { Spacer(minLength: 60) }
        }
    }
}

struct CoachCardView: View {
    let card: CoachCard; let onDismiss: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: card.ratingIcon).font(.system(size: 14, weight: .semibold))
                    .foregroundColor(card.ratingColor)
                Text("Cyrano").font(RWF.micro()).foregroundColor(.rwAccent).tracking(1.5)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                        .foregroundColor(.rwTextMuted).frame(width: 24, height: 24)
                        .background(Color.rwSurface).clipShape(Circle())
                }
            }
            Text(card.headline).font(RWF.head(14)).foregroundColor(.rwTextPrimary)
            Text(card.insight).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "arrow.right.circle.fill").font(.system(size: 12))
                    .foregroundColor(card.ratingColor)
                Text(card.tip).font(RWF.body(13)).foregroundColor(card.ratingColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SP.md)
        .background(card.ratingColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(card.ratingColor.opacity(0.2), lineWidth: 1.5))
        .shadow(color: card.ratingColor.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

struct DebriefSection: View {
    let icon: String; let title: String; let text: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(RWF.cap()).foregroundColor(color)
            Text(text).font(RWF.body()).foregroundColor(.rwTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SP.md).background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(color.opacity(0.15), lineWidth: 1))
    }
}
