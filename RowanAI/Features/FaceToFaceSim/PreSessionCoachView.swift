import SwiftUI

// MARK: - Pre-Session Coach (3-slide briefing)
// Sits between SimPreSessionView (Cyrano brief) and SimSessionView (live).
// Three slides — Skill / Focus Tip / Win Condition — swiped with a TabView
// page style. "Skip" jumps straight to the session for users who've already
// practiced this personality.

struct PreSessionCoachView: View {
    let avatar: SimAvatar
    let environment: SimEnvironment
    let personality: SimPersonality
    let mode: SimMode
    let returnToPicker: () -> Void
    let restartSession: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var page: Int = 0
    @State private var startSession: Bool = false
    @State private var seenBefore: Bool = false

    private static let seenKeyPrefix = "presession.coach.seen."

    private var seenKey: String {
        Self.seenKeyPrefix + personality.rawValue
    }

    private var accentStart: Color { Color(hex: avatar.gradientStart) }
    private var accentEnd:   Color { Color(hex: avatar.gradientEnd) }
    private var personalityGradient: LinearGradient {
        LinearGradient(colors: [accentStart, accentEnd],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        ZStack {
            // Dark cinematic backdrop with a personality-tinted halo so the
            // coach view feels continuous with the live session below.
            LinearGradient.cinematic.ignoresSafeArea()
            RadialGradient(colors: [accentStart.opacity(0.22), .clear],
                           center: .top, startRadius: 0, endRadius: 420)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                TabView(selection: $page) {
                    skillSlide.tag(0)
                    focusSlide.tag(1)
                    winSlide.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: page)

                pageDots

                bottomCTA
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            seenBefore = UserDefaults.standard.bool(forKey: seenKey)
            UserDefaults.standard.set(true, forKey: seenKey)
        }
        .fullScreenCover(isPresented: $startSession) {
            SimSessionView(
                avatar: avatar,
                environment: environment,
                personality: personality,
                mode: mode,
                returnToPicker: returnToPicker,
                restartSession: restartSession
            )
        }
    }

    // MARK: - Top bar (close + skip)

    private var topBar: some View {
        HStack {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.rwInkText)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.rwInkBorder, lineWidth: 1))
            }

            Spacer()

            // "Skip" — visible always, prominent if seen before.
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                startSession = true
            } label: {
                HStack(spacing: 6) {
                    Text("Skip").font(RWF.cap(13))
                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.rwInkText)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(seenBefore
                            ? AnyShapeStyle(personalityGradient.opacity(0.85))
                            : AnyShapeStyle(Color.white.opacity(0.10)))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.rwInkBorder, lineWidth: 1))
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.top, 60).padding(.horizontal, 20).padding(.bottom, 8)
    }

    // MARK: - Slide 1 — The skill this session trains

    private var skillSlide: some View {
        slideShell {
            VStack(spacing: 26) {
                slideEyebrow("STEP 1 OF 3 · YOUR SKILL")

                ZStack {
                    Circle().fill(personalityGradient)
                        .frame(width: 110, height: 110)
                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1.5))
                        .shadow(color: accentStart.opacity(0.5), radius: 24, x: 0, y: 12)
                    Image(systemName: personality.icon)
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(spacing: 12) {
                    Text("Today you're practicing")
                        .font(RWF.cap(13)).foregroundColor(.rwInkTextMuted).tracking(1.4)
                    Text(personality.coachSkillName)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(personalityGradient)
                        .multilineTextAlignment(.center)
                }

                Text(personality.coachSkillRationale)
                    .font(RWF.body(15)).foregroundColor(.rwInkText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)

                researchPill(personality.coachResearchSource,
                             quote: personality.coachResearchQuote)
            }
        }
    }

    // MARK: - Slide 2 — The one thing to focus on

    private var focusSlide: some View {
        slideShell {
            VStack(spacing: 24) {
                slideEyebrow("STEP 2 OF 3 · ONE FOCUS")

                Image(systemName: "scope")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(personalityGradient)
                    .padding(20)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                    .overlay(Circle().stroke(Color.rwInkBorder, lineWidth: 1))

                VStack(spacing: 12) {
                    Text("The one thing")
                        .font(RWF.cap(13)).foregroundColor(.rwInkTextMuted).tracking(1.4)
                    Text(personality.coachFocusTip)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.rwInkText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("WHY")
                        .font(RWF.micro()).foregroundColor(.rwInkTextMuted).tracking(1.4)
                    Text(personality.coachFocusContext)
                        .font(RWF.body(14)).foregroundColor(.rwInkText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SP.md)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: RR.lg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: RR.lg, style: .continuous)
                    .stroke(Color.rwInkBorder, lineWidth: 1))
            }
        }
    }

    // MARK: - Slide 3 — The win condition

    private var winSlide: some View {
        slideShell {
            VStack(spacing: 24) {
                slideEyebrow("STEP 3 OF 3 · WIN CONDITION")

                Image(systemName: "trophy.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(personalityGradient)
                    .padding(20)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                    .overlay(Circle().stroke(Color.rwInkBorder, lineWidth: 1))
                    .shadow(color: accentStart.opacity(0.4), radius: 18, x: 0, y: 10)

                Text("How you win this session")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.rwInkText)
                    .multilineTextAlignment(.center)

                Text(personality.coachWinDescription)
                    .font(RWF.body(15)).foregroundColor(.rwInkText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)

                VStack(spacing: 10) {
                    bulletRow(icon: "eye.fill",
                              title: "Cyrano is watching for",
                              text: personality.coachCyranoWatch)
                    bulletRow(icon: "waveform.path.ecg",
                              title: "Engagement meter responds to",
                              text: personality.coachMeterResponds)
                }
            }
        }
    }

    // MARK: - Slide chrome

    private func slideShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(showsIndicators: false) {
            VStack { content() }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 16)
        }
    }

    private func slideEyebrow(_ text: String) -> some View {
        Text(text)
            .font(RWF.micro()).foregroundColor(.rwInkTextMuted).tracking(1.6)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.rwInkBorder, lineWidth: 1))
    }

    private func researchPill(_ source: String, quote: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(source.uppercased())
                .font(RWF.micro()).foregroundColor(accentStart).tracking(1.4)
            Text("\u{201C}\(quote)\u{201D}")
                .font(RWF.body(13)).italic().foregroundColor(.rwInkText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SP.md)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: RR.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RR.lg, style: .continuous)
            .stroke(Color.rwInkBorder, lineWidth: 1))
    }

    private func bulletRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(personalityGradient)
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(0.08)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(RWF.micro()).foregroundColor(.rwInkTextMuted).tracking(1.2)
                Text(text)
                    .font(RWF.body(13)).foregroundColor(.rwInkText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SP.sm)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: RR.md, style: .continuous))
    }

    // MARK: - Dot indicators

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i == page ? AnyShapeStyle(personalityGradient) : AnyShapeStyle(Color.white.opacity(0.20)))
                    .frame(width: i == page ? 22 : 7, height: 7)
                    .animation(.spring(response: 0.32, dampingFraction: 0.85), value: page)
            }
        }
        .padding(.vertical, 14)
    }

    // MARK: - Bottom CTA

    @ViewBuilder
    private var bottomCTA: some View {
        if page == 2 {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                startSession = true
            } label: {
                HStack(spacing: 10) {
                    Text("Start Session").font(RWF.head(16))
                    Image(systemName: "arrow.right").font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(personalityGradient)
                .clipShape(RoundedRectangle(cornerRadius: RR.xl, style: .continuous))
                .shadow(color: accentStart.opacity(0.45), radius: 18, x: 0, y: 10)
            }
            .padding(.horizontal, 20).padding(.bottom, 38)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation { page = min(page + 1, 2) }
            } label: {
                HStack(spacing: 8) {
                    Text("Next").font(RWF.cap(13))
                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.rwInkText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: RR.xl, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: RR.xl, style: .continuous)
                    .stroke(Color.rwInkBorder, lineWidth: 1))
            }
            .padding(.horizontal, 20).padding(.bottom, 38)
        }
    }
}

// MARK: - Personality coaching content
// Lives next to the view that uses it. Each personality has six lines:
// skill name + rationale + research source/quote, focus tip + context,
// win description + Cyrano-watch + meter-responds.

extension SimPersonality {

    var coachSkillName: String {
        switch self {
        case .guarded:         return "Earning Trust"
        case .teaser:          return "Creating Intrigue"
        case .distracted:      return "Holding Attention"
        case .confrontational: return "Staying Grounded"
        case .overthinker:     return "Creating Safety"
        case .socialButterfly: return "Deepening Connection"
        }
    }

    var coachSkillRationale: String {
        switch self {
        case .guarded:
            return "Trust isn't a switch — it's an accumulation of small, non-extractive moments where they felt seen without feeling exposed. The people who get through aren't the most charming. They're the ones who don't try to break in."
        case .teaser:
            return "Intrigue is the gap between expected and surprising. Match-and-lift is how you tell someone you can keep up — and that you're worth their attention. Earnestness too early collapses the gap."
        case .distracted:
            return "Attention in a stimulating room is a competitive resource. You're not fighting their interest — you're competing with everything else in the room. Specific beats generic every time."
        case .confrontational:
            return "Direct people use friction as a filter. They're not trying to win — they're checking whether there's a real person behind your words. Calm conviction passes the test."
        case .overthinker:
            return "Their nervous system is scanning for ambiguity. Specificity is oxygen. Every concrete word you use is a small reassurance their brain doesn't have to fill in."
        case .socialButterfly:
            return "Their warmth is automatic. Real connection is the work. The people who get past the surface slow down and ask one curious question they haven't been asked before."
        }
    }

    var coachResearchSource: String {
        switch self {
        case .guarded:         return "Amir Levine · Attached"
        case .teaser:          return "Esther Perel · Mating in Captivity"
        case .distracted:      return "John Gottman · The Relationship Cure"
        case .confrontational: return "John Gottman · The Four Horsemen research"
        case .overthinker:     return "Amir Levine · Attached"
        case .socialButterfly: return "Esther Perel · The State of Affairs"
        }
    }

    var coachResearchQuote: String {
        switch self {
        case .guarded:
            return "Avoidant attachment isn't a refusal of closeness — it's a strategy that worked when closeness wasn't safe."
        case .teaser:
            return "Desire requires distance. The unknown, the unsaid, the slightly out of reach — these are the conditions for play."
        case .distracted:
            return "Bids for connection are the smallest unit of a relationship. They are missed not because they are weak, but because they are unspecific."
        case .confrontational:
            return "Defensiveness is the mirror of criticism. Stay grounded and the cycle breaks."
        case .overthinker:
            return "Anxious attachment quiets when met with consistent, specific reassurance — not extravagance."
        case .socialButterfly:
            return "Warmth is the opening line. Curiosity is the second sentence. Most people never write it."
        }
    }

    var coachFocusTip: String {
        switch self {
        case .guarded:
            return "Ask one question about something they actually said — not a generic question."
        case .teaser:
            return "Match their energy. If they're playful go playful. Don't be serious when they're not."
        case .distracted:
            return "Say something surprising. Generic keeps losing them. Unexpected keeps them."
        case .confrontational:
            return "Don't fold and don't fight. Hold your position calmly with \u{201C}I see it differently.\u{201D}"
        case .overthinker:
            return "Give them space. Don't rush to fill silence. Let them come to you."
        case .socialButterfly:
            return "Find the thread they keep coming back to. That's what they actually care about."
        }
    }

    var coachFocusContext: String {
        switch self {
        case .guarded:
            return "Specific recall is the loudest possible signal that you're paying attention. Quoting them back proves you're not running a script. Generic questions feel like an interrogation."
        case .teaser:
            return "Energy mismatch is the fastest disengagement signal a teaser registers. Lift the rhythm and they stay; flatten it and they're already half-gone."
        case .distracted:
            return "You're not competing for interest — you're competing with every other thing in the room. Surprise reroutes attention faster than enthusiasm."
        case .confrontational:
            return "Folding reads as performance. Fighting reads as ego. Calmly holding a position reads as a real person with real opinions — and that's what they're testing for."
        case .overthinker:
            return "Filling silence makes them spiral; pressure makes them collapse. Trust the pause. They'll fill it themselves with something true."
        case .socialButterfly:
            return "They'll tell you exactly what matters by what they keep returning to. Your job is to notice the loop and pull on that thread, not invite a new one."
        }
    }

    var coachWinDescription: String {
        switch self {
        case .guarded:
            return "They share something specific without you asking, and the conversation slows into a real pace. That's the unlock."
        case .teaser:
            return "They tease you back. They reach for the next exchange instead of waiting for it. The energy stays lifted across multiple turns."
        case .distracted:
            return "They turn toward you. Their eyes stop drifting. They ask a follow-up question that goes deeper than the room around you."
        case .confrontational:
            return "The pressure drops. They warm into the conversation because you didn't perform for them — you stayed yourself."
        case .overthinker:
            return "They relax. Their answers get longer and less anxious. They stop checking themselves mid-sentence."
        case .socialButterfly:
            return "They drop the easy charm. They ask you something they haven't asked before. The pace slows."
        }
    }

    var coachCyranoWatch: String {
        switch self {
        case .guarded:
            return "Specific callbacks. Patient pacing. Sharing a small piece of yourself before extracting one from them."
        case .teaser:
            return "Banter rhythm. Speed of return. Whether you can hold the lift across 3+ turns without going earnest."
        case .distracted:
            return "Specificity, surprise, and message length. Long blocks lose them; sharp lines win them back."
        case .confrontational:
            return "Whether you placate, escalate, or hold. They warm to the third one only."
        case .overthinker:
            return "Concreteness, action language (\u{201C}I want to\u{201D} not \u{201C}maybe\u{201D}), and whether you reflect back what they said."
        case .socialButterfly:
            return "Vertical depth on a single thread vs. horizontal new topics. Slowdown signals you're real."
        }
    }

    var coachMeterResponds: String {
        switch self {
        case .guarded:
            return "Drops on pressure or generic questions. Climbs on specific curiosity and reciprocal small disclosures."
        case .teaser:
            return "Drops on flat or earnest replies. Climbs when you tease back warmly or surprise them with something specific."
        case .distracted:
            return "Drops on generic openers and long blocks. Climbs on a single concrete observation that reroutes attention."
        case .confrontational:
            return "Drops on apologies, hedges, and \u{201C}I just thought\u{201D} phrasing. Climbs when you disagree warmly."
        case .overthinker:
            return "Drops on ambiguity, sarcasm, and short non-answers. Climbs on specificity and reflective acknowledgement."
        case .socialButterfly:
            return "Drops on surface volleying. Climbs when you slow the pace and go deeper on something they brought up."
        }
    }
}
