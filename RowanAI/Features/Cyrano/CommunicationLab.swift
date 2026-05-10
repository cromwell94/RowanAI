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
                        title: "The 20 Lessons",
                        description: "Real communication patterns — what kills connection and what builds it. Short, honest, practical.",
                        color: Color(hex: "5B8DEF"),
                        tag: store.isPro ? "All 20 Unlocked" : "3 Free · 17 Pro",
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

    struct ModuleGroup {
        let number: Int
        let name: String
        let lessons: [LabLesson]
    }

    let lessons: [LabLesson] = [
        // MARK: Module 1 — Presence (1-3 free, 4 Pro)
        LabLesson(
            number: 1, isFree: true,
            module: 1, moduleName: "Presence",
            title: "The Interview Pattern",
            subtitle: "Why asking questions without sharing yourself kills connection",
            icon: "questionmark.bubble.fill",
            color: Color(hex: "5B8DEF"),
            fullContent: "Most people treat early conversations like job interviews — question after question with nothing shared in return. This feels safe but kills connection. The other person ends up feeling interrogated, not seen. The fix is simple: match every question with a brief disclosure. \"Where are you from?\" becomes \"Where are you from? I grew up in Jersey so I'm always curious about other people's hometowns.\" You're not dominating the conversation — you're making it a two-way street. Research by Arthur Aron shows that mutual self-disclosure is the single strongest predictor of connection speed. The question isn't the connection. The sharing is.",
            keyInsight: "For every question you ask, share something about yourself first or after.",
            research: "Arthur Aron's fast friendship study, 1997.",
            quizQuestion: "You just asked where someone grew up. What should you do next?",
            quizAnswer: "Share where you grew up."
        ),
        LabLesson(
            number: 2, isFree: true,
            module: 1, moduleName: "Presence",
            title: "Solving vs Listening",
            subtitle: "The difference that changes everything",
            icon: "ear.fill",
            color: Color(hex: "E8356D"),
            fullContent: "When someone shares a problem, the male-coded brain jumps to solutions. The female-coded brain often jumps to empathy. Neither is wrong — but the timing matters enormously. John Gottman's research found that 69% of relationship conflicts are perpetual — they never get solved. What people actually want in those moments isn't a solution. They want to feel understood. The next time someone shares something difficult, try this: reflect before you fix. \"That sounds really frustrating\" before \"Have you tried...\" changes the entire dynamic. Solutions feel dismissive when delivered too early. The same solution delivered after genuine acknowledgment lands completely differently.",
            keyInsight: "Reflect first. Fix second. Most of the time reflecting is enough.",
            research: "John Gottman, The Seven Principles for Making Marriage Work.",
            quizQuestion: "Your date says work has been really stressful lately. What's the best first response?",
            quizAnswer: "Acknowledge the feeling before offering advice."
        ),
        LabLesson(
            number: 3, isFree: true,
            module: 1, moduleName: "Presence",
            title: "Specificity Over Flattery",
            subtitle: "Why 'you're so interesting' lands worse than you think",
            icon: "star.fill",
            color: Color(hex: "F59E0B"),
            fullContent: "\"You're so interesting\" is the conversational equivalent of a participation trophy. It signals that you're paying attention but doesn't prove it. Specific observations do both. \"The way you talked about your sister — I can tell that relationship really shaped you\" lands in a completely different place than generic compliments. Specificity requires actual listening. It can't be faked. And because it can't be faked, it builds trust faster than any compliment. Matthew Hussey calls this \"earned appreciation\" — appreciation that demonstrates you were actually present, not just performing interest.",
            keyInsight: "Replace generic compliments with specific observations that prove you were listening.",
            research: "Matthew Hussey, Get the Guy. Cialdini's research on genuine vs performative interest.",
            quizQuestion: "Your date just finished telling you about their passion project. What's the better response?",
            quizAnswer: "Reference a specific detail they mentioned rather than saying 'that's so cool.'"
        ),
        LabLesson(
            number: 4, isFree: false,
            module: 1, moduleName: "Presence",
            title: "Energy Matching",
            subtitle: "Reading the room — and your own nervous system",
            icon: "waveform",
            color: Color(hex: "9B59B6"),
            fullContent: "Emotional energy is contagious in both directions. Walk into a conversation nervous and scattered and you'll make the other person feel unsettled. Walk in grounded and genuinely curious and you'll regulate their nervous system without trying. This is co-regulation — a concept from attachment neuroscience. Your calm literally transfers. The practical application: before any date or important conversation, spend 60 seconds breathing slowly and thinking of something you're genuinely curious about regarding this person. Not what you want them to think of you. What you actually want to know about them. That shift in internal state changes your entire external presence.",
            keyInsight: "Your nervous system regulates theirs. Get calm first.",
            research: "Stephen Porges, Polyvagal Theory. Sue Johnson, Hold Me Tight.",
            quizQuestion: "You're nervous before a first date. What's the most effective thing to do in the 60 seconds before you walk in?",
            quizAnswer: "Focus on something you're genuinely curious about them, not on how you want to come across."
        ),

        // MARK: Module 2 — Curiosity (Pro)
        LabLesson(
            number: 5, isFree: false,
            module: 2, moduleName: "Curiosity",
            title: "The Follow-Up Question",
            subtitle: "Stay one exchange longer than feels natural",
            icon: "arrow.turn.down.right",
            color: Color(hex: "5B8DEF"),
            fullContent: "Most people ask a question, get an answer, and move to the next topic. This is conversational channel surfing. The follow-up question — asking about what was just said instead of moving on — signals that you actually heard the answer. \"You mentioned you used to paint. Do you still?\" is more connecting than any new question you could introduce. Esther Perel calls this \"sustained curiosity\" — the willingness to stay with a subject long enough to actually learn something. One follow-up question per topic is the minimum standard for genuine connection.",
            keyInsight: "Stay with a topic one exchange longer than feels natural before moving on.",
            research: "Esther Perel, Mating in Captivity.",
            quizQuestion: "Your date mentions they used to paint. What's the most connecting next move?",
            quizAnswer: "Ask a follow-up about painting before introducing a new topic."
        ),
        LabLesson(
            number: 6, isFree: false,
            module: 2, moduleName: "Curiosity",
            title: "The Assumption Flip",
            subtitle: "Replace some questions with playful guesses",
            icon: "arrow.triangle.2.circlepath",
            color: Color(hex: "9B59B6"),
            fullContent: "Instead of asking a question, make a playful assumption and let them correct you. \"You seem like someone who has strong opinions about coffee\" opens a conversation differently than \"Do you like coffee?\" Assumptions invite pushback, reveal personality, and create micro-moments of tension that feel interesting rather than clinical. Logan Ury's behavioral research found that people remember conversations where they felt slightly challenged far longer than conversations where they felt completely comfortable.",
            keyInsight: "Replace some questions with curious assumptions. Let them correct you.",
            research: "Logan Ury, How to Not Die Alone.",
            quizQuestion: "Instead of asking 'do you like traveling?' what's the assumption version?",
            quizAnswer: "\"You seem like someone who has a trip already planned.\""
        ),
        LabLesson(
            number: 7, isFree: false,
            module: 2, moduleName: "Curiosity",
            title: "What They Don't Say",
            subtitle: "Track what's avoided as carefully as what's said",
            icon: "eye.slash.fill",
            color: Color(hex: "E8356D"),
            fullContent: "The most revealing information in any conversation is often what's avoided. If someone talks extensively about work but never mentions family, that gap is data. If someone laughs off a question about past relationships, the laugh is data. Active listening means tracking not just what's said but what's consistently absent or deflected. This isn't about prying — it's about noticing patterns and following up gently when the moment is right. \"You light up talking about your work — is that the biggest thing in your life right now?\" opens a door without forcing it.",
            keyInsight: "Track what's consistently avoided or deflected. That's where the real story often lives.",
            research: "Paul Ekman, Emotions Revealed.",
            quizQuestion: "Someone keeps changing the subject when family comes up. What's the right move?",
            quizAnswer: "Note it and gently revisit once, then respect the boundary."
        ),
        LabLesson(
            number: 8, isFree: false,
            module: 2, moduleName: "Curiosity",
            title: "Curiosity vs Interest Performance",
            subtitle: "The shift that makes you actually compelling",
            icon: "sparkles",
            color: Color(hex: "F59E0B"),
            fullContent: "There's a difference between being curious and performing interest. Performed interest looks like nodding, saying wow and that's so cool on a loop, and asking questions from a checklist. Genuine curiosity has a different quality — it surprises even you. You didn't plan to ask that question; it came from actually listening. The shift from performance to genuine curiosity requires one thing: caring less about how you're coming across and more about actually understanding this person. Paradoxically the less you try to seem interested the more interesting you become.",
            keyInsight: "Genuine curiosity cannot be performed. It comes from actually caring about the answer.",
            research: "Brené Brown, Daring Greatly.",
            quizQuestion: "What's the sign you've shifted from genuine curiosity to performing interest?",
            quizAnswer: "You're thinking of your next question while they're still talking."
        ),

        // MARK: Module 3 — Vulnerability (Pro)
        LabLesson(
            number: 9, isFree: false,
            module: 3, moduleName: "Vulnerability",
            title: "The Disclosure Ladder",
            subtitle: "Match their depth and lead by a half-step",
            icon: "chart.line.uptrend.xyaxis",
            color: Color(hex: "5B8DEF"),
            fullContent: "Vulnerability has levels. Sharing that you love hiking is level 1. Sharing that you started hiking after a really dark period and it saved you is level 7. Healthy connection moves gradually up the ladder — not starting at 1 and never moving, and not skipping to 10 on a first date. The disclosure ladder means calibrating your depth to match where the conversation is and gently moving it forward. Research by Brené Brown found that people who share at slightly deeper levels than the conversation calls for are perceived as more trustworthy and interesting — not oversharing, just leading by a half-step.",
            keyInsight: "Share at slightly deeper levels than the conversation requires. Lead by a half-step.",
            research: "Brené Brown, The Gifts of Imperfection.",
            quizQuestion: "Your date shares something moderately personal. What's the ideal response?",
            quizAnswer: "Match their depth and add one slightly deeper detail of your own."
        ),
        LabLesson(
            number: 10, isFree: false,
            module: 3, moduleName: "Vulnerability",
            title: "Owning Your Story",
            subtitle: "Talk about your past with accountability, not victimhood",
            icon: "book.closed.fill",
            color: Color(hex: "9B59B6"),
            fullContent: "How you talk about your past relationship history reveals everything about your self-awareness. \"She was crazy\" is a red flag to a perceptive person. \"That relationship taught me I wasn't great at communicating what I needed\" is the same story told with accountability. You don't have to air all your dirty laundry on a first date — but when the topic comes up, the language you use matters. Ownership without self-flagellation. \"I've learned\" rather than \"I was a victim of\" or \"I was terrible.\" Logan Ury calls this narrative maturity — the ability to integrate your past without being defined or destroyed by it.",
            keyInsight: "Own your story without performing victimhood or self-punishment.",
            research: "Logan Ury, How to Not Die Alone.",
            quizQuestion: "Your date asks about your last relationship. What's the best framing?",
            quizAnswer: "One honest sentence about what you learned, nothing more."
        ),
        LabLesson(
            number: 11, isFree: false,
            module: 3, moduleName: "Vulnerability",
            title: "Strategic Imperfection",
            subtitle: "Small admissions create more connection than perfect confidence",
            icon: "sparkle",
            color: Color(hex: "F59E0B"),
            fullContent: "People don't fall for your highlight reel. They fall for the moment you admit you don't have it all figured out. This doesn't mean dumping your anxieties on someone on a first date. It means allowing small genuine imperfections to surface naturally. \"I'm actually a little nervous — I don't usually admit that\" said with a smile creates more connection than a perfect performance of confidence. Matthew Hussey calls this charming vulnerability — the ability to be genuinely imperfect in a way that invites others in rather than making them feel responsible for fixing you.",
            keyInsight: "Small genuine admissions of imperfection create more connection than perfect confidence.",
            research: "Matthew Hussey, Get the Guy. Robert Cialdini, Influence.",
            quizQuestion: "You fumble over your words telling a story. What's the best response?",
            quizAnswer: "Laugh at yourself lightly and keep going — don't over-apologize."
        ),
        LabLesson(
            number: 12, isFree: false,
            module: 3, moduleName: "Vulnerability",
            title: "Venting vs Sharing",
            subtitle: "One offloads, one connects",
            icon: "bubble.left.and.bubble.right.fill",
            color: Color(hex: "00BFB3"),
            fullContent: "Venting is processing your emotions out loud with no regard for the other person's experience. Sharing is offering something true about yourself in a way that invites connection. The difference is intention. Venting seeks relief. Sharing seeks understanding. In early connection especially the distinction matters enormously. One session of real sharing builds more trust than a year of surface conversation. One extended venting session can make someone feel like an emotional dumping ground. The test: are you sharing to connect, or are you offloading to feel better?",
            keyInsight: "Share to connect, not to offload. Ask yourself which one you're doing before you start.",
            research: "Esther Perel on the difference between intimacy and emotional dependency.",
            quizQuestion: "You had a terrible day and want to talk about it on a second date. What's the right approach?",
            quizAnswer: "Share one true thing about how you're feeling, then genuinely ask about them."
        ),

        // MARK: Module 4 — Repair (Pro)
        LabLesson(
            number: 13, isFree: false,
            module: 4, moduleName: "Repair",
            title: "The 5:1 Ratio",
            subtitle: "Five positive moments for every difficult one",
            icon: "chart.bar.fill",
            color: Color(hex: "5B8DEF"),
            fullContent: "John Gottman's most famous finding: stable relationships have a 5:1 ratio of positive to negative interactions. Five moments of warmth, humor, connection, or affirmation for every one moment of criticism, tension, or withdrawal. This doesn't mean avoiding hard conversations — it means the emotional bank account needs enough deposits to survive the withdrawals. In early dating this translates simply: don't let the first challenging moment define the connection. One awkward silence, one fumbled joke, one slightly weird comment — none of these are fatal if the ratio of good moments is high enough.",
            keyInsight: "Five positive moments to one negative. Keep the ratio, not the score.",
            research: "John Gottman, Why Marriages Succeed or Fail.",
            quizQuestion: "There was one awkward moment in an otherwise great date. How should you weigh it?",
            quizAnswer: "One negative against many positive is exactly the 5:1 ratio working as intended. Don't overweight it."
        ),
        LabLesson(
            number: 14, isFree: false,
            module: 4, moduleName: "Repair",
            title: "Repair Attempts",
            subtitle: "The skill that predicts connection health",
            icon: "wrench.and.screwdriver.fill",
            color: Color(hex: "E8356D"),
            fullContent: "A repair attempt is any gesture — verbal or physical — that tries to de-escalate tension. \"Can we start over?\" \"I didn't mean it like that.\" A well-timed laugh. A touch on the arm. Gottman found that the success of repair attempts is the single best predictor of relationship health — not the absence of conflict but the ability to recover from it. The skill is twofold: making repair attempts AND being open to receiving them. Many people are so defended when hurt that they block repairs without noticing. Learning to recognize and accept a repair is as important as making one.",
            keyInsight: "The ability to repair matters more than the absence of conflict.",
            research: "John Gottman, The Seven Principles for Making Marriage Work.",
            quizQuestion: "Your date makes a joke to lighten tension after a slightly awkward exchange. What is that?",
            quizAnswer: "A repair attempt. Receive it."
        ),
        LabLesson(
            number: 15, isFree: false,
            module: 4, moduleName: "Repair",
            title: "The Non-Defensive Response",
            subtitle: "Acknowledge before you defend",
            icon: "shield.lefthalf.filled",
            color: Color(hex: "9B59B6"),
            fullContent: "When someone criticizes you or raises a concern the automatic response is defensiveness. Defensiveness is a wall. It communicates I care more about being right than about your experience. The non-defensive response is not agreement — it's acknowledgment. \"I can see why that landed wrong\" is not the same as \"you're right, I'm terrible.\" It's receiving the other person's experience without immediately trying to correct it. This is one of the hardest communication skills to develop because it requires tolerating the discomfort of feeling criticized without reacting immediately.",
            keyInsight: "Acknowledge before you defend. You can clarify your intentions after you've heard them out.",
            research: "John Gottman, The Four Horsemen — criticism, contempt, defensiveness, stonewalling.",
            quizQuestion: "Someone says your joke earlier made them uncomfortable. First response?",
            quizAnswer: "\"I'm sorry — that wasn't my intention. Can you tell me more about how it landed?\""
        ),
        LabLesson(
            number: 16, isFree: false,
            module: 4, moduleName: "Repair",
            title: "Rupture and Repair as Bonding",
            subtitle: "Successful repair builds more trust than no tension at all",
            icon: "heart.fill",
            color: Color(hex: "00BFB3"),
            fullContent: "Paradoxically, successfully navigating a moment of tension can create more closeness than smooth sailing. When two people have a small conflict and repair it well they learn something essential: this relationship can handle difficulty. That knowledge creates safety. Esther Perel describes the energy that returns after tension is resolved as a kind of rekindling. In early connection this means not avoiding all conflict but handling the inevitable bumps with enough grace that they become proof of connection rather than evidence against it.",
            keyInsight: "Successful repair after tension creates more trust than no tension at all.",
            research: "Esther Perel, The State of Affairs.",
            quizQuestion: "You and your date have a minor disagreement and resolve it well. What did that just do?",
            quizAnswer: "Built more trust than if the disagreement had never happened."
        ),

        // MARK: Module 5 — Consistency (Pro)
        LabLesson(
            number: 17, isFree: false,
            module: 5, moduleName: "Consistency",
            title: "Showing Up the Same Way Twice",
            subtitle: "Reliability beats peak moments",
            icon: "repeat",
            color: Color(hex: "5B8DEF"),
            fullContent: "Consistency is underrated as an attraction quality. Most people focus on being impressive. Fewer focus on being reliable. But the nervous system of a potential partner is tracking patterns: do you show up the same way twice? Is your warmth consistent or contingent? Do you follow through on small things? These micro-patterns communicate safety faster than any grand gesture. Logan Ury's research on long-term relationship satisfaction found that perceived reliability in the first month of dating is one of the strongest predictors of relationship quality at year two.",
            keyInsight: "Small consistent actions build more trust than occasional grand gestures.",
            research: "Logan Ury, How to Not Die Alone.",
            quizQuestion: "You were warm and engaged on date one. How important is it to show up the same way on date two?",
            quizAnswer: "Critical. Consistency is what the nervous system is tracking, not peak moments."
        ),
        LabLesson(
            number: 18, isFree: false,
            module: 5, moduleName: "Consistency",
            title: "The Follow-Through Gap",
            subtitle: "The space between what you say and what you do",
            icon: "checkmark.circle.fill",
            color: Color(hex: "00BFB3"),
            fullContent: "\"We should do that sometime\" said and never followed up on is one of the most common connection killers in early dating. The follow-through gap — the distance between what you say and what you do — is noticed even when people don't consciously track it. The fix is simple: only say things you intend to do. \"I'll send you that article\" followed by actually sending it is more connecting than ten compliments. \"I'd love to try that restaurant you mentioned\" followed by a specific suggestion builds more trust than a month of good conversation.",
            keyInsight: "Follow through on small things. They are not small.",
            research: "Robert Cialdini, Influence — commitment and consistency principle.",
            quizQuestion: "You told someone you'd send them a podcast recommendation. Three days pass. What do you do?",
            quizAnswer: "Send it with a one-line note. Late follow-through beats no follow-through."
        ),
        LabLesson(
            number: 19, isFree: false,
            module: 5, moduleName: "Consistency",
            title: "Presence Over Frequency",
            subtitle: "Quality of attention beats volume of contact",
            icon: "eye.fill",
            color: Color(hex: "F59E0B"),
            fullContent: "Texting someone fifteen times a day while being mentally absent during actual time together is the modern paradox of connection. Frequency is not presence. Presence is the quality of attention you bring when you're actually together. One hour of full attention — phone face down, genuinely listening, making eye contact — builds more connection than a week of constant but distracted contact. This is increasingly rare which makes it increasingly valuable. Being the person who is actually present when present is a significant differentiator.",
            keyInsight: "Quality of attention matters more than frequency of contact.",
            research: "Sherry Turkle, Reclaiming Conversation.",
            quizQuestion: "You text someone constantly but check your phone during dinner with them. What signal are you sending?",
            quizAnswer: "That the phone is more important than they are, regardless of how much you text."
        ),
        LabLesson(
            number: 20, isFree: false,
            module: 5, moduleName: "Consistency",
            title: "The Long Game",
            subtitle: "Give attraction time to compound",
            icon: "hourglass",
            color: Color(hex: "9B59B6"),
            fullContent: "Real attraction compounds. The first date is not the whole story. Many of the most significant relationships start with a 6 or a 7, not a 10. The nervous system's initial read is based on threat assessment and pattern matching from the past — not necessarily on who this person actually is. Giving connection time to develop rather than making a final verdict after one meeting is one of the most underrated relationship skills. Logan Ury calls this slow love — the willingness to let attraction deepen over time rather than demanding it be fully formed at first sight.",
            keyInsight: "Give attraction time. A 7 who becomes a 10 over three dates beats a 10 who stays a 10.",
            research: "Logan Ury, How to Not Die Alone. Helen Fisher on attraction timelines.",
            quizQuestion: "You had a fine but not fireworks first date. Should you go on a second?",
            quizAnswer: "Almost always yes. Attraction compounds. First dates are the worst data point."
        ),
    ]

    private var moduleGroups: [ModuleGroup] {
        let grouped = Dictionary(grouping: lessons, by: \.module)
        return grouped.keys.sorted().map { num in
            let inModule = (grouped[num] ?? []).sorted { $0.number < $1.number }
            return ModuleGroup(number: num, name: inModule.first?.moduleName ?? "", lessons: inModule)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.rwTextPrimary).frame(width: 36, height: 36)
                        .background(Color.rwSurface).clipShape(Circle())
                }
                Spacer()
                Text("The 20 Lessons").font(RWF.head()).foregroundColor(.rwTextPrimary)
                Spacer()
                Spacer().frame(width: 36)
            }
            .padding(.horizontal, SP.lg).padding(.vertical, 14)
            RWLine()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    if !store.isPro {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill").font(.system(size: 11))
                            Text("Lessons 4–20 require Pro. Lessons 1–3 are free.")
                                .font(RWF.cap(12))
                        }
                        .foregroundColor(.rwTextMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    }

                    ForEach(moduleGroups, id: \.number) { mod in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Text("MODULE \(mod.number)")
                                    .font(RWF.micro())
                                    .foregroundColor(.rwTextMuted)
                                    .tracking(1.5)
                                Text("·").foregroundColor(.rwTextMuted)
                                Text(mod.name.uppercased())
                                    .font(RWF.micro())
                                    .foregroundColor(.rwAccent)
                                    .tracking(1.5)
                                Spacer()
                            }
                            VStack(spacing: 8) {
                                ForEach(mod.lessons) { lesson in
                                    if lesson.isFree || store.isPro {
                                        Button { selected = lesson } label: { LessonRow(lesson: lesson, locked: false) }
                                            .buttonStyle(SBS())
                                    } else {
                                        Button { showPaywall = true } label: { LessonRow(lesson: lesson, locked: true) }
                                            .buttonStyle(SBS())
                                    }
                                }
                            }
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
    @State private var quizRevealed = false

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
                            HStack(spacing: 6) {
                                Text("MODULE \(lesson.module)")
                                    .font(RWF.micro()).foregroundColor(.rwTextMuted).tracking(1.4)
                                Text("·").foregroundColor(.rwTextMuted)
                                Text(lesson.moduleName.uppercased())
                                    .font(RWF.micro()).foregroundColor(.rwAccent).tracking(1.4)
                            }
                            Text(lesson.title).font(RWF.title(20)).foregroundColor(.rwTextPrimary)
                        }
                    }

                    // Lesson body
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Lesson", systemImage: "book.fill")
                            .font(RWF.cap()).foregroundColor(.rwTextMuted)
                        Text(lesson.fullContent)
                            .font(RWF.body(15)).foregroundColor(.rwTextPrimary)
                            .fixedSize(horizontal: false, vertical: true).lineSpacing(5)
                    }

                    // Key insight callout
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(lesson.color)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Key insight").font(RWF.cap()).foregroundColor(.rwTextMuted).tracking(1.2)
                            Text(lesson.keyInsight).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                                .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
                        }
                    }
                    .padding(SP.md).background(lesson.color.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                    .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(lesson.color.opacity(0.2), lineWidth: 1))

                    // Research footnote
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Research", systemImage: "books.vertical.fill")
                            .font(RWF.cap()).foregroundColor(.rwTextMuted)
                        Text(lesson.research)
                            .font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                            .italic()
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    RWLine()

                    // Quiz — tap to reveal
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Quick check", systemImage: "questionmark.circle.fill")
                            .font(RWF.cap()).foregroundColor(.rwAccent)
                        Text(lesson.quizQuestion)
                            .font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                            .fixedSize(horizontal: false, vertical: true).lineSpacing(3)

                        if quizRevealed {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "00BFB3"))
                                    .padding(.top, 1)
                                Text(lesson.quizAnswer)
                                    .font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
                            }
                            .padding(SP.md)
                            .background(Color(hex: "00BFB3").opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color(hex: "00BFB3").opacity(0.2), lineWidth: 1))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    quizRevealed = true
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "eye.fill").font(.system(size: 13))
                                    Text("Tap to reveal answer").font(RWF.med(14))
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 12))
                                }
                                .foregroundColor(.rwAccent)
                                .padding(SP.md)
                                .background(Color.rwAccent.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwAccent.opacity(0.25), lineWidth: 1))
                            }
                            .buttonStyle(SBS())
                        }
                    }

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
    let module: Int; let moduleName: String
    let title: String; let subtitle: String; let icon: String; let color: Color
    let fullContent: String
    let keyInsight: String
    let research: String
    let quizQuestion: String
    let quizAnswer: String
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
