import SwiftUI

// MARK: - Flow

struct OnboardingFlowView: View {
    @Environment(AppState.self) var app
    @State private var step = 0
    @State private var user = RWUser()

    // Step-graph routing: relationship-mode users skip dating-only screens
    // (DatingGoal, FirstRelationship) and pick up the partner-detail subflow.
    // Single / complicated users skip the partner subflow.
    private func next(after current: Int) -> Int {
        let isRel = user.relationshipStatus == .relationship
        switch current {
        case 0:  return 1            // Welcome → Language
        case 1:  return 2            // Language → Disclosure
        case 2:  return 3            // Disclosure → RelStatus
        case 3:  return isRel ? 4 : 8 // RelStatus → PartnerName | Gender
        case 4:  return 5            // PartnerName → Duration
        case 5:  return 6            // Duration → Goals
        case 6:  return 7            // Goals → PartnerInvite
        case 7:  return 8            // PartnerInvite → Gender
        case 8:  return isRel ? 10 : 9 // Gender → AttachQuiz | DatingGoal
        case 9:  return 10           // DatingGoal → AttachQuiz
        case 10: return 11           // AttachQuiz → LoveLanguage
        case 11: return isRel ? 13 : 12 // LoveLanguage → Name | FirstRel
        case 12: return 13           // FirstRel → Name
        default: return current + 1
        }
    }

    private func advance() { step = next(after: step) }

    private func finish() {
        // Mirror relationship status onto AppState so HomeView's mode picker
        // (rwAccent vs rwGold) and the Relationship tab visibility light up
        // immediately on first launch.
        if user.relationshipStatus == .relationship {
            app.switchToKeepMode()
        }
        AuthService.shared.save(user)
        app.hasCompletedOnboarding = true
    }

    var body: some View {
        ZStack {
            Color.rwBackground.ignoresSafeArea()
            switch step {
            case 0:  WelcomeView { advance() }
            case 1:  LanguageView(user: $user) { advance() }
            case 2:  DisclosureView { advance() }
            case 3:  RelationshipStatusView(user: $user) { advance() }
            case 4:  PartnerNameView(user: $user) { advance() }
            case 5:  RelationshipDurationView(user: $user) { advance() }
            case 6:  RelationshipGoalsView(user: $user) { advance() }
            case 7:  PartnerInviteView(user: $user) { advance() }
            case 8:  GenderView(user: $user) { advance() }
            case 9:  GoalView(user: $user) { advance() }
            case 10: AttachQuizView(user: $user) { advance() }
            case 11: LoveLanguageView(user: $user) { advance() }
            case 12: FirstRelationshipView(user: $user) { advance() }
            case 13: NameView(user: $user) { finish() }
            default: EmptyView()
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: step)
    }
}

// MARK: - Header
// Onboarding screens get the premium page-header look: gradient eyebrow,
// SF Pro Rounded display title, generous breathing room.

struct OBHead: View {
    let step: String; let title: String; let sub: String
    @State private var on = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(step.uppercased())
                .font(RWF.micro())
                .foregroundStyle(LinearGradient.accent)
                .tracking(1.8)
                .padding(.top, 64)
                .opacity(on ? 1 : 0)
            Text(title)
                .font(RWF.display(34))
                .foregroundColor(.rwTextPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(on ? 1 : 0)
                .offset(y: on ? 0 : 14)
            Text(sub)
                .font(RWF.body(16))
                .foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(on ? 1 : 0)
                .offset(y: on ? 0 : 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SP.xl)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.05)) { on = true }
        }
    }
}

// MARK: - Welcome

struct WelcomeView: View {
    let next: () -> Void
    @State private var on = false
    @State private var haloPulse = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo + soft accent halo — the brand moment that opens the app.
            ZStack {
                Circle()
                    .fill(LinearGradient.accent.opacity(0.18))
                    .frame(width: 220, height: 220)
                    .scaleEffect(haloPulse ? 1.08 : 1.0)
                    .blur(radius: 30)
                Circle()
                    .fill(Color.rwAccent.opacity(0.10))
                    .frame(width: 140, height: 140)
                    .blur(radius: 12)
                RowanLogo(size: 80)
                    .scaleEffect(on ? 1 : 0.6)
                    .opacity(on ? 1 : 0)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                    haloPulse.toggle()
                }
            }

            Spacer().frame(height: 28)

            VStack(spacing: 10) {
                Text("rowan")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient.accent)
                Text("Built for love. Not likes.")
                    .font(RWF.med(16))
                    .foregroundColor(.rwTextSecondary)
            }
            .opacity(on ? 1 : 0)
            .offset(y: on ? 0 : 16)

            Spacer().frame(height: 48)

            VStack(spacing: 10) {
                Pill(icon: "bubble.left.and.bubble.right.fill", text: "Real-time message coaching")
                    .staggerAppear(0, appeared: on)
                Pill(icon: "person.2.fill",                    text: "Your connections, organised")
                    .staggerAppear(1, appeared: on)
                Pill(icon: "heart.text.square.fill",           text: "From first match to lasting love")
                    .staggerAppear(2, appeared: on)
            }

            Spacer()

            RWButton("Get Started", icon: "arrow.right") { next() }
                .padding(.horizontal, SP.xl)
                .padding(.bottom, 56)
                .opacity(on ? 1 : 0)
        }
        .frame(maxHeight: .infinity)
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.1)) { on = true } }
    }
}

struct Pill: View {
    let icon: String; let text: String
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: RR.sm).fill(Color.rwAccent.opacity(0.1)).frame(width: 38, height: 38)
                Image(systemName: icon).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundColor(.rwAccent)
            }
            Text(text).font(RWF.med(15)).foregroundColor(.rwTextPrimary)
            Spacer()
            Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(.rwAccent.opacity(0.5))
        }
        .padding(.horizontal, SP.lg).padding(.vertical, SP.md)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
        .padding(.horizontal, SP.xl)
    }
}

// MARK: - Disclosure

struct DisclosureView: View {
    let next: () -> Void
    @State private var agreed = false
    @State private var aiConsent = false
    @State private var on = false
    @State private var showTerms = false
    @State private var showAITerms = false

    let items: [(String, String, String)] = [
        ("cpu",                          "AI Coaching",               "Rowan uses Cyrano, an AI relationship coach, to help you communicate better and build genuine connections."),
        ("lock.shield.fill",             "Your Data",                 "All personal data stays on your device. Only messages you send to AI features are transmitted externally. Your data is never sold."),
        ("exclamationmark.triangle.fill","AI Can Be Wrong",           "Suggestions may be inaccurate. Always use your own judgment. Rowan is not responsible for outcomes."),
        ("person.slash.fill",            "Not Professional Advice",   "Not a licensed therapist or counselor. An AI tool only. Seek professional help for serious concerns."),
        ("cross.fill",                   "Crisis Resources",          "If you are in a mental health emergency call 988 (US) or your local emergency services."),
        ("hand.raised.fill",             "Content Policy",            "Rowan generates dating and relationship coaching only. Never explicit content.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(systemName: "shield.checkered").font(.system(size: 40, design: .rounded)).foregroundColor(.rwAccent).padding(.top, 56)
                Text("Before You Begin").font(RWF.display(26)).foregroundColor(.rwTextPrimary)
                Text("Please read and agree before using Rowan.").font(RWF.body()).foregroundColor(.rwTextSecondary)
            }
            .opacity(on ? 1 : 0)

            Spacer().frame(height: 24)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(items, id: \.1) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.0).font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.rwAccent)
                                .frame(width: 40, height: 40)
                                .background(Color.rwAccent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: RR.md))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.1).font(RWF.head(14)).foregroundColor(.rwTextPrimary)
                                Text(item.2).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(SP.md).background(Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                    }

                    // AI Consent — required by Apple
                    Button { withAnimation { aiConsent.toggle() } } label: {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(aiConsent ? Color(hex: "5B8DEF") : Color.rwBorder, lineWidth: 2)
                                    .frame(width: 22, height: 22)
                                if aiConsent { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(Color(hex: "5B8DEF")) }
                            }.padding(.top, 1)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("I agree to Cyrano's AI Terms")
                                    .font(RWF.body(13)).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button { showAITerms = true } label: {
                                    Text("Learn more →").font(RWF.cap()).foregroundColor(Color(hex: "5B8DEF")).underline()
                                }
                            }
                        }
                        .padding(SP.md)
                        .background(aiConsent ? Color(hex: "5B8DEF").opacity(0.06) : Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(aiConsent ? Color(hex: "5B8DEF").opacity(0.4) : Color.rwBorder, lineWidth: aiConsent ? 1.5 : 1))
                    }
                    .buttonStyle(SBS())

                    // Terms consent
                    Button { withAnimation { agreed.toggle() } } label: {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(agreed ? Color.rwAccent : Color.rwBorder, lineWidth: 2)
                                    .frame(width: 22, height: 22)
                                if agreed { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.rwAccent) }
                            }.padding(.top, 1)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("I agree to the Terms of Service and Privacy Policy")
                                    .font(RWF.body(13)).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button { showTerms = true } label: {
                                    Text("Read full Terms →").font(RWF.cap()).foregroundColor(.rwAccent).underline()
                                }
                            }
                        }
                        .padding(SP.md)
                        .background(agreed ? Color.rwAccent.opacity(0.06) : Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(agreed ? Color.rwAccent.opacity(0.3) : Color.rwBorder, lineWidth: 1))
                    }
                }
                .padding(.horizontal, SP.xl).padding(.bottom, 16)
            }

            Spacer()

            RWButton("Agree and Continue", icon: "checkmark.shield.fill") { next() }
                .disabled(!agreed || !aiConsent).opacity((agreed && aiConsent) ? 1 : 0.5)
                .padding(.horizontal, SP.xl).padding(.bottom, 44)
                .opacity(on ? 1 : 0)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { on = true } }
        .sheet(isPresented: $showTerms) { TermsSheet() }
        .sheet(isPresented: $showAITerms) { CyranoAITermsSheet() }
    }
}

// MARK: - Cyrano AI Terms Sheet

struct CyranoAITermsSheet: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: SP.lg) {
                    Text("About Cyrano").font(RWF.title()).foregroundColor(.rwTextPrimary)
                    Text("Cyrano is Rowan's AI relationship coach. Cyrano's responses are generated with the help of Anthropic's AI technology. By using Cyrano, you consent to your messages being processed by Anthropic.")
                        .font(RWF.body(14)).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Link("View Anthropic's privacy policy at anthropic.com/privacy →",
                         destination: URL(string: "https://www.anthropic.com/privacy")!)
                        .font(RWF.body(13)).foregroundColor(Color(hex: "5B8DEF"))
                    Spacer().frame(height: 40)
                }
                .padding(SP.xl)
            }
            .rwBG()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.foregroundColor(.rwAccent) } }
        }
    }
}

// MARK: - Gender

struct GenderView: View {
    @Binding var user: RWUser
    let next: () -> Void
    @State private var on = false

    var body: some View {
        VStack(spacing: 0) {
            OBHead(step: "2 of 6", title: "How do you\nexperience dating?", sub: "This shapes every piece of coaching you receive.")
                .opacity(on ? 1 : 0)
            Spacer().frame(height: 32)
            VStack(spacing: 12) {
                ForEach(RWUser.Gender.allCases, id: \.rawValue) { g in
                    GCard(g: g, sel: user.gender == g) { user.gender = g }
                        .opacity(on ? 1 : 0)
                }
            }
            .padding(.horizontal, SP.xl)
            Spacer()
            RWButton("Continue", icon: "arrow.right") { next() }
                .padding(.horizontal, SP.xl).padding(.bottom, 44).opacity(on ? 1 : 0)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { on = true } }
    }
}

struct GCard: View {
    let g: RWUser.Gender; let sel: Bool; let tap: () -> Void
    var color: Color {
        switch g { case .male: return Color(hex: "6B7FD7"); case .female: return .rwAccent; case .preferNotToSay: return .rwGold }
    }
    var body: some View {
        Button(action: tap) {
            HStack(spacing: 14) {
                Image(systemName: "person.fill")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(sel ? .white : color)
                    .frame(width: 46, height: 46)
                    .background(sel ? color : color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                Text(g.rawValue).font(RWF.head(17)).foregroundColor(.rwTextPrimary)
                Spacer(minLength: 0)
                if sel { Image(systemName: "checkmark.circle.fill").foregroundColor(color).font(.system(size: 20, design: .rounded)) }
            }
            .padding(SP.lg)
            .background(sel ? color.opacity(0.08) : Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(sel ? color.opacity(0.5) : Color.rwBorder, lineWidth: sel ? 1.5 : 1))
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Goal

struct GoalView: View {
    @Binding var user: RWUser; let next: () -> Void
    @State private var on = false
    var body: some View {
        VStack(spacing: 0) {
            OBHead(step: "3 of 6", title: "What are you\nlooking for?", sub: "This shapes how I coach you.").opacity(on ? 1 : 0)
            Spacer().frame(height: 32)
            VStack(spacing: 12) {
                ForEach(RWUser.DatingGoal.allCases, id: \.rawValue) { g in
                    Button { user.datingGoal = g } label: {
                        HStack(spacing: 14) {
                            Image(systemName: g.icon).font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundColor(user.datingGoal == g ? .white : .rwAccent)
                                .frame(width: 46, height: 46)
                                .background(user.datingGoal == g ? Color.rwAccent : Color.rwAccent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: RR.md))
                            Text(g.rawValue).font(RWF.head()).foregroundColor(.rwTextPrimary)
                            Spacer()
                            if user.datingGoal == g { Image(systemName: "checkmark.circle.fill").foregroundColor(.rwAccent).font(.system(size: 20, design: .rounded)) }
                        }
                        .padding(SP.lg)
                        .background(user.datingGoal == g ? Color.rwAccent.opacity(0.08) : Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(user.datingGoal == g ? Color.rwAccent.opacity(0.5) : Color.rwBorder, lineWidth: user.datingGoal == g ? 1.5 : 1))
                    }
                    .buttonStyle(SBS()).opacity(on ? 1 : 0)
                }
            }
            .padding(.horizontal, SP.xl)
            Spacer()
            RWButton("Continue", icon: "arrow.right") { next() }
                .padding(.horizontal, SP.xl).padding(.bottom, 44).opacity(on ? 1 : 0)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { on = true } }
    }
}

// MARK: - Attachment Style Quiz (ECR-R, 12 items)
// Shortened ECR-R based on Brennan, Clark & Shaver (1998). Six anxiety items
// + six avoidance items, 5-point Likert. Means above 3 = "high"; the
// (anxiety, avoidance) quadrant maps to one of four canonical styles.

struct ECRItem {
    let prompt: String
    let dimension: Dimension
    let reverse: Bool
    enum Dimension { case anxiety, avoidance }
}

private let ecrItems: [ECRItem] = [
    .init(prompt: "I prefer not to show people how I feel deep down.",
          dimension: .avoidance, reverse: false),
    .init(prompt: "I worry about being abandoned by people I'm close to.",
          dimension: .anxiety,   reverse: false),
    .init(prompt: "I find it difficult to allow myself to depend on romantic partners.",
          dimension: .avoidance, reverse: false),
    .init(prompt: "I'm afraid that romantic partners won't care about me as much as I care about them.",
          dimension: .anxiety,   reverse: false),
    .init(prompt: "I'm nervous when partners get too close to me.",
          dimension: .avoidance, reverse: false),
    .init(prompt: "I often wish that romantic partners' feelings for me were as strong as my feelings for them.",
          dimension: .anxiety,   reverse: false),
    .init(prompt: "I try to avoid getting too close to romantic partners.",
          dimension: .avoidance, reverse: false),
    .init(prompt: "I worry a lot about my relationships.",
          dimension: .anxiety,   reverse: false),
    .init(prompt: "I feel comfortable depending on romantic partners.",
          dimension: .avoidance, reverse: true),
    .init(prompt: "When I show my feelings for romantic partners, I'm afraid they will not feel the same about me.",
          dimension: .anxiety,   reverse: false),
    .init(prompt: "It's easy for me to be affectionate with romantic partners.",
          dimension: .avoidance, reverse: true),
    .init(prompt: "I rarely worry about my partner leaving me.",
          dimension: .anxiety,   reverse: true),
]

private func scoreECR(_ answers: [Int]) -> RWUser.AttachmentStyle {
    var anxietySum = 0.0, anxietyN = 0.0
    var avoidanceSum = 0.0, avoidanceN = 0.0
    for (idx, raw) in answers.enumerated() where idx < ecrItems.count {
        let item = ecrItems[idx]
        let score = item.reverse ? Double(6 - raw) : Double(raw)
        switch item.dimension {
        case .anxiety:   anxietySum   += score; anxietyN   += 1
        case .avoidance: avoidanceSum += score; avoidanceN += 1
        }
    }
    let anxiety   = anxietyN   > 0 ? anxietySum   / anxietyN   : 3.0
    let avoidance = avoidanceN > 0 ? avoidanceSum / avoidanceN : 3.0
    let highAnx = anxiety   > 3.0
    let highAvd = avoidance > 3.0
    switch (highAnx, highAvd) {
    case (false, false): return .secure
    case (true,  false): return .anxiousPreoccupied
    case (false, true):  return .dismissiveAvoidant
    case (true,  true):  return .fearfulAvoidant
    }
}

struct AttachQuizView: View {
    @Binding var user: RWUser
    let next: () -> Void

    @State private var stage: Stage = .intro
    @State private var index = 0
    @State private var answers: [Int] = []
    @State private var on = false

    enum Stage { case intro, quiz, result }

    private let likert: [(value: Int, label: String)] = [
        (1, "Strongly\nDisagree"),
        (2, "Disagree"),
        (3, "Neutral"),
        (4, "Agree"),
        (5, "Strongly\nAgree"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            switch stage {
            case .intro:  intro
            case .quiz:   quiz
            case .result: result
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { on = true } }
    }

    // MARK: Intro

    private var intro: some View {
        VStack(spacing: 0) {
            OBHead(step: "Attachment Style",
                   title: "How do you show\nup in love?",
                   sub: "12 quick statements. There are no right answers — just rate how true each one feels for you.")
                .opacity(on ? 1 : 0)
            Spacer().frame(height: 32)
            VStack(alignment: .leading, spacing: 12) {
                bullet(icon: "clock.fill", text: "Takes about 90 seconds")
                bullet(icon: "lock.fill", text: "Stays on your device")
                bullet(icon: "sparkles",   text: "Shapes how Cyrano coaches you")
            }
            .padding(.horizontal, SP.xl)
            .opacity(on ? 1 : 0)
            Spacer()
            RWButton("Begin", icon: "arrow.right") {
                withAnimation { stage = .quiz; index = 0; answers = [] }
            }
            .padding(.horizontal, SP.xl)
            .opacity(on ? 1 : 0)
            Button("Skip — I'll set this later") {
                user.attachmentStyle = .secure
                next()
            }
            .font(RWF.cap()).foregroundColor(.rwTextMuted)
            .padding(.top, 12).padding(.bottom, 44)
            .opacity(on ? 1 : 0)
        }
    }

    private func bullet(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.rwAccent)
                .frame(width: 32, height: 32)
                .background(Color.rwAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: RR.sm))
            Text(text).font(RWF.body(14)).foregroundColor(.rwTextPrimary)
            Spacer()
        }
    }

    // MARK: Quiz

    private var quiz: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(0..<ecrItems.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < answers.count ? Color.rwAccent : Color.rwBorder)
                        .frame(maxWidth: .infinity).frame(height: 3)
                }
            }
            .padding(.horizontal, SP.xl).padding(.top, 60).padding(.bottom, 28)

            Text("Question \(index + 1) of \(ecrItems.count)")
                .font(RWF.cap()).foregroundColor(.rwTextMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SP.xl)
                .padding(.bottom, 8)

            Text(ecrItems[index].prompt)
                .font(RWF.title(22))
                .foregroundColor(.rwTextPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SP.xl)
                .padding(.bottom, 32)
                .id("q\(index)") // force transition redraw

            VStack(spacing: 8) {
                ForEach(likert, id: \.value) { opt in
                    Button {
                        record(answer: opt.value)
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(opt.value)")
                                .font(RWF.head(15))
                                .foregroundColor(.rwAccent)
                                .frame(width: 32, height: 32)
                                .background(Color.rwAccent.opacity(0.1))
                                .clipShape(Circle())
                            Text(opt.label.replacingOccurrences(of: "\n", with: " "))
                                .font(RWF.body(15))
                                .foregroundColor(.rwTextPrimary)
                            Spacer()
                        }
                        .padding(SP.md)
                        .background(Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                    }
                    .buttonStyle(SBS())
                }
            }
            .padding(.horizontal, SP.xl)

            Spacer()

            if index > 0 {
                Button {
                    withAnimation {
                        if !answers.isEmpty { answers.removeLast() }
                        index = max(0, index - 1)
                    }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(RWF.cap()).foregroundColor(.rwTextMuted)
                }
                .padding(.bottom, 32)
            }
        }
    }

    private func record(answer value: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        var updated = answers
        if updated.count > index {
            updated[index] = value
        } else {
            updated.append(value)
        }
        answers = updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if index < ecrItems.count - 1 {
                withAnimation { index += 1 }
            } else {
                let style = scoreECR(answers)
                user.attachmentStyle = style
                withAnimation { stage = .result }
            }
        }
    }

    // MARK: Result

    private var result: some View {
        let style = user.attachmentStyle
        return VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                Image(systemName: style.icon)
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .foregroundColor(style.color)
                    .frame(width: 96, height: 96)
                    .background(style.color.opacity(0.12))
                    .clipShape(Circle())
                VStack(spacing: 6) {
                    Text("Your attachment style").font(RWF.body()).foregroundColor(.rwTextSecondary)
                    Text(style.rawValue).font(RWF.display(28)).foregroundColor(.rwTextPrimary)
                    Text(style.description)
                        .font(RWF.body()).foregroundColor(.rwTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SP.xl)
                        .fixedSize(horizontal: false, vertical: true)
                }
                RWCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("How Cyrano uses this", systemImage: "sparkles")
                            .font(RWF.cap()).foregroundColor(.rwTextMuted)
                        Text("Coaching adapts to your style — what to watch for, what to lean into, where you're likely to misread someone.")
                            .font(RWF.body()).foregroundColor(.rwTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, SP.xl)
            }
            Spacer()
            RWButton("Looks right — continue", icon: "arrow.right") { next() }
                .padding(.horizontal, SP.xl)
            Text("Brief assessment based on Brennan, Clark & Shaver (1998). Not a clinical diagnosis. You can retake this anytime in Profile.")
                .font(.system(size: 11, design: .rounded)).foregroundColor(.rwTextMuted)
                .multilineTextAlignment(.center).padding(.horizontal, SP.xl).padding(.top, 8)
            Button("Retake quiz") {
                withAnimation { stage = .quiz; index = 0; answers = [] }
            }
            .font(RWF.cap()).foregroundColor(.rwTextMuted)
            .padding(.top, 6).padding(.bottom, 44)
        }
    }
}

// MARK: - Name

struct NameView: View {
    @Binding var user: RWUser; let done: () -> Void
    @State private var on = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            OBHead(step: "7 of 8", title: "Last thing —\nwhat's your name?", sub: "I'll use this to personalise your experience.").opacity(on ? 1 : 0)
            Spacer().frame(height: 40)
            TextField("", text: $user.name, prompt: Text("Your first name").foregroundColor(.rwTextMuted))
                .font(RWF.head(20)).foregroundColor(.rwTextPrimary)
                .padding(SP.lg).background(Color.rwCard)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(focused ? Color.rwAccent.opacity(0.5) : Color.rwBorder, lineWidth: 1))
                .focused($focused).autocorrectionDisabled().textInputAutocapitalization(.words)
                .padding(.horizontal, SP.xl).opacity(on ? 1 : 0)
            Spacer()
            RWButton(user.name.isEmpty ? "Continue" : "Let's go, \(user.name) →", icon: nil) { done() }
                .padding(.horizontal, SP.xl).padding(.bottom, 44)
                .disabled(user.name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(user.name.isEmpty ? 0.5 : 1).opacity(on ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { on = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focused = true }
        }
    }
}


// MARK: - Love Language Step

struct LoveLanguageView: View {
    @Binding var user: RWUser
    let next: () -> Void
    @State private var mode: LLMode = .choose
    @State private var quizIndex = 0
    @State private var quizAnswers: [Int] = []
    @State private var showResult = false
    @State private var on = false

    enum LLMode { case choose, quiz, pick }

    let questions: [(prompt: String, options: [(text: String, lang: LoveLanguage)])] = [
        (
            "After a long week, what would mean the most?",
            [
                ("Your partner tells you how much they appreciate you", .words),
                ("They handle something stressful for you", .acts),
                ("They surprise you with a thoughtful gift", .gifts),
                ("They put their phone down and just be with you", .time),
                ("They greet you with a long hug", .touch)
            ]
        ),
        (
            "You feel most connected when your partner...",
            [
                ("Sends you a heartfelt message out of nowhere", .words),
                ("Does the dishes without being asked", .acts),
                ("Brings you something they saw and thought of you", .gifts),
                ("Plans a full day just for the two of you", .time),
                ("Holds your hand while you walk", .touch)
            ]
        ),
        (
            "In a new relationship, what signals real interest?",
            [
                ("They say exactly the right thing at the right moment", .words),
                ("They show up when things get hard", .acts),
                ("They remember what you like and act on it", .gifts),
                ("They carve out real time for you", .time),
                ("They're naturally physically affectionate", .touch)
            ]
        ),
        (
            "What would hurt most in a relationship?",
            [
                ("Being criticised or never complimented", .words),
                ("Feeling like they never help or put in effort", .acts),
                ("Being forgotten on important occasions", .gifts),
                ("Always being second to their phone or friends", .time),
                ("Feeling physically distant or untouched", .touch)
            ]
        ),
        (
            "On a perfect date, the highlight would be...",
            [
                ("A deep conversation where they really see you", .words),
                ("They planned every detail to make it easy for you", .acts),
                ("They brought you something small but meaningful", .gifts),
                ("Hours passed and it felt like minutes", .time),
                ("A moment of closeness — a touch, a look", .touch)
            ]
        )
    ]

    var quizResult: LoveLanguage {
        var counts: [LoveLanguage: Int] = [:]
        for answer in quizAnswers {
            if quizIndex <= questions.count, answer < questions[min(quizIndex, questions.count-1)].options.count {
                // tally already done
            }
        }
        // Tally from all 5 questions
        for (qi, ai) in quizAnswers.enumerated() {
            if qi < questions.count && ai < questions[qi].options.count {
                let lang = questions[qi].options[ai].lang
                counts[lang, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? .time
    }

    var body: some View {
        VStack(spacing: 0) {
            switch mode {
            case .choose: chooseMode
            case .quiz:   quizMode
            case .pick:   pickMode
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { on = true } }
    }

    var chooseMode: some View {
        VStack(spacing: 0) {
            OBHead(step: "6 of 8", title: "Your Love Language", sub: "How you give and receive love shapes everything.")
                .opacity(on ? 1 : 0)
            Spacer().frame(height: 40)
            VStack(spacing: 14) {
                Button {
                    withAnimation { mode = .quiz; quizIndex = 0; quizAnswers = [] }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                            .background(LinearGradient.accent)
                            .clipShape(RoundedRectangle(cornerRadius: RR.md))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Take the Quiz").font(RWF.head(17)).foregroundColor(.rwTextPrimary)
                            Text("5 quick questions — 60 seconds").font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
                    }
                    .padding(SP.lg).background(Color.rwCard)
                    .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                    .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
                    .shadow(color: Color.rwShadow, radius: 12, x: 0, y: 2)
                }
                .buttonStyle(SBS()).opacity(on ? 1 : 0)

                Button {
                    withAnimation { mode = .pick }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.rwTextSecondary)
                            .frame(width: 52, height: 52)
                            .background(Color.rwSurface)
                            .clipShape(RoundedRectangle(cornerRadius: RR.md))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("I Already Know Mine").font(RWF.head(17)).foregroundColor(.rwTextPrimary)
                            Text("Pick one or multiple").font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
                    }
                    .padding(SP.lg).background(Color.rwCard)
                    .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                    .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
                    .shadow(color: Color.rwShadow, radius: 12, x: 0, y: 2)
                }
                .buttonStyle(SBS()).opacity(on ? 1 : 0)
            }
            .padding(.horizontal, SP.xl)
            Spacer()
            Button("Skip for now") { next() }
                .font(RWF.cap()).foregroundColor(.rwTextMuted)
                .padding(.bottom, 44).opacity(on ? 1 : 0)
        }
    }

    var quizMode: some View {
        VStack(spacing: 0) {
            if showResult {
                quizResultView
            } else {
                VStack(spacing: 0) {
                    // Progress
                    HStack(spacing: 6) {
                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(i < quizAnswers.count ? Color.rwAccent : Color.rwBorder)
                                .frame(maxWidth: .infinity).frame(height: 4)
                        }
                    }
                    .padding(.horizontal, SP.xl).padding(.top, 60).padding(.bottom, 32)

                    Text(questions[quizIndex].prompt)
                        .font(RWF.title(22)).foregroundColor(.rwTextPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, SP.xl)
                        .padding(.bottom, 28)

                    VStack(spacing: 10) {
                        ForEach(Array(questions[quizIndex].options.enumerated()), id: \.offset) { i, opt in
                            Button {
                                var newAnswers = quizAnswers
                                if quizAnswers.count > quizIndex {
                                    newAnswers[quizIndex] = i
                                } else {
                                    newAnswers.append(i)
                                }
                                quizAnswers = newAnswers
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    if quizIndex < questions.count - 1 {
                                        withAnimation { quizIndex += 1 }
                                    } else {
                                        // Done — tally result
                                        user.loveLanguages = [quizResult]
                                        withAnimation { showResult = true }
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Text(opt.text).font(RWF.body()).foregroundColor(.rwTextPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                }
                                .padding(SP.md).background(Color.rwCard)
                                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                                .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
                            }
                            .buttonStyle(SBS())
                        }
                    }
                    .padding(.horizontal, SP.xl)
                    Spacer()
                }
            }
        }
    }

    var quizResultView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: quizResult.icon)
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .foregroundColor(quizResult.color)
                    .frame(width: 100, height: 100)
                    .background(quizResult.color.opacity(0.1))
                    .clipShape(Circle())

                VStack(spacing: 8) {
                    Text("Your love language is")
                        .font(RWF.body()).foregroundColor(.rwTextSecondary)
                    Text(quizResult.rawValue)
                        .font(RWF.display(30)).foregroundColor(.rwTextPrimary)
                    Text(quizResult.shortDescription)
                        .font(RWF.body()).foregroundColor(.rwTextSecondary)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }

                RWCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("What this means for dating", systemImage: "heart.text.square.fill")
                            .font(RWF.cap()).foregroundColor(.rwTextMuted)
                        Text(quizResult.datingImplication)
                            .font(RWF.body()).foregroundColor(.rwTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, SP.xl)
            }
            Spacer()
            RWButton("Looks right — continue", icon: "arrow.right") { next() }
                .padding(.horizontal, SP.xl)
            Text("Based on Gary Chapman's Love Languages framework. For a full 30-question assessment visit 5lovelanguages.com")
                .font(.system(size: 11, design: .rounded)).foregroundColor(.rwTextMuted)
                .multilineTextAlignment(.center).padding(.horizontal, SP.xl)

            Button("Retake quiz") {
                withAnimation { showResult = false; quizIndex = 0; quizAnswers = [] }
            }
            .font(RWF.cap()).foregroundColor(.rwTextMuted).padding(.top, 8).padding(.bottom, 44)
        }
    }

    var pickMode: some View {
        VStack(spacing: 0) {
            OBHead(step: "6 of 8", title: "Pick Your Love Language(s)", sub: "Choose as many as feel true.")
            Spacer().frame(height: 32)
            VStack(spacing: 12) {
                ForEach(LoveLanguage.allCases) { lang in
                    let selected = user.loveLanguages.contains(lang)
                    Button {
                        if selected {
                            user.loveLanguages.removeAll { $0 == lang }
                        } else {
                            user.loveLanguages.append(lang)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: lang.icon)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(selected ? .white : lang.color)
                                .frame(width: 46, height: 46)
                                .background(selected ? lang.color : lang.color.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: RR.md))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(lang.rawValue).font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                                Text(lang.shortDescription).font(RWF.body(12)).foregroundColor(.rwTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(lang.color).font(.system(size: 20, design: .rounded))
                            }
                        }
                        .padding(SP.md)
                        .background(selected ? lang.color.opacity(0.06) : Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                        .overlay(RoundedRectangle(cornerRadius: RR.xl)
                            .stroke(selected ? lang.color.opacity(0.4) : Color.rwBorder,
                                    lineWidth: selected ? 1.5 : 1))
                        .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
                    }
                    .buttonStyle(SBS())
                }
            }
            .padding(.horizontal, SP.xl)
            Spacer()
            RWButton("Continue", icon: "arrow.right") { next() }
                .padding(.horizontal, SP.xl).padding(.bottom, 44)
                .disabled(user.loveLanguages.isEmpty)
                .opacity(user.loveLanguages.isEmpty ? 0.5 : 1)
        }
    }
}




// MARK: - Language Selection View

struct LanguageView: View {
    @Binding var user: RWUser
    let next: () -> Void
    @State private var on = false

    var body: some View {
        VStack(spacing: 0) {
            OBHead(step: "1 of 8", title: "Choose your language.", sub: "Cyrano will coach you in the language you choose.")
                .opacity(on ? 1 : 0)

            Spacer().frame(height: 24)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(AppLanguage.allCases) { lang in
                        Button { user.preferredLanguage = lang } label: {
                            HStack(spacing: 10) {
                                Text(lang.flag).font(.system(size: 24, design: .rounded))
                                Text(lang.rawValue).font(RWF.med(14)).foregroundColor(.rwTextPrimary)
                                Spacer()
                                if user.preferredLanguage == lang {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.rwAccent).font(.system(size: 16, design: .rounded))
                                }
                            }
                            .padding(SP.md)
                            .background(user.preferredLanguage == lang ? Color.rwAccent.opacity(0.06) : Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                            .overlay(RoundedRectangle(cornerRadius: RR.xl)
                                .stroke(user.preferredLanguage == lang ? Color.rwAccent.opacity(0.4) : Color.rwBorder,
                                        lineWidth: user.preferredLanguage == lang ? 1.5 : 1))
                        }
                        .buttonStyle(SBS())
                        .animation(.spring(response: 0.3), value: user.preferredLanguage)
                    }
                }
                .padding(.horizontal, SP.xl)
            }
            .opacity(on ? 1 : 0)

            Spacer()

            RWButton("Continue", icon: "arrow.right") { next() }
                .padding(.horizontal, SP.xl).padding(.bottom, 44)
                .opacity(on ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) { on = true } }
    }
}

// MARK: - First Relationship View

struct FirstRelationshipView: View {
    @Binding var user: RWUser
    let next: () -> Void
    @State private var on = false

    var body: some View {
        VStack(spacing: 0) {
            OBHead(step: "7 of 8", title: "Is this your first relationship?", sub: "Rowan tailors its support based on your experience.")
                .opacity(on ? 1 : 0)

            Spacer().frame(height: 40)

            VStack(spacing: 12) {
                FirstRelCard(
                    title: "Yes, my first",
                    sub: "I want guidance on what healthy looks like",
                    icon: "heart.fill",
                    color: Color(hex: "E8356D"),
                    selected: user.isFirstRelationship == true
                ) {
                    user.isFirstRelationship = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }

                FirstRelCard(
                    title: "No, I have experience",
                    sub: "I know the basics but always learning",
                    icon: "checkmark.seal.fill",
                    color: Color(hex: "00BFB3"),
                    selected: user.isFirstRelationship == false
                ) {
                    user.isFirstRelationship = false
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
            .padding(.horizontal, SP.xl)
            .opacity(on ? 1 : 0)

            Spacer()

            VStack(spacing: 10) {
                RWButton("Continue", icon: "arrow.right") { next() }
                    .disabled(user.isFirstRelationship == nil)
                    .opacity(user.isFirstRelationship == nil ? 0.5 : 1)
                Button("Skip") { next() }
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
            }
            .padding(.horizontal, SP.xl).padding(.bottom, 44)
            .opacity(on ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) { on = true } }
    }
}

struct FirstRelCard: View {
    let title: String; let sub: String; let icon: String; let color: Color
    let selected: Bool; let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(selected ? .white : color)
                    .frame(width: 52, height: 52)
                    .background(selected ? color : color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                    Text(sub).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(color).font(.system(size: 20, design: .rounded))
                }
            }
            .padding(SP.lg)
            .background(selected ? color.opacity(0.06) : Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl)
                .stroke(selected ? color.opacity(0.4) : Color.rwBorder,
                        lineWidth: selected ? 1.5 : 1))
            .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
        }
        .buttonStyle(SBS())
        .animation(.spring(response: 0.3), value: selected)
    }
}

// MARK: - Terms Sheet

struct TermsSheet: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: SP.lg) {
                    Text("Terms of Service & Privacy Policy").font(RWF.title()).foregroundColor(.rwTextPrimary)
                    Text("Last updated: April 2026").font(RWF.cap()).foregroundColor(.rwTextMuted)
                    TB(t: "What RowanAI Is", b: "An AI-powered dating assistant. NOT a licensed therapist or relationship professional.")
                    TB(t: "AI Limitations", b: "AI suggestions may be wrong. Following them does not guarantee any outcome. Use your own judgment.")
                    TB(t: "Content Policy", b: "RowanAI generates flirtatious and romantic coaching only. Never sexually explicit content. This is a firm policy.")
                    TB(t: "Not a Crisis Resource", b: "If you are in a mental health emergency, call 988 (US) or emergency services. RowanAI cannot handle emergencies.")
                    TB(t: "Your Data", b: "Stored on your device by default. Never sold. Delete anytime from Profile → Settings.")
                    TB(t: "Age Requirement", b: "You must be 18 or older to use RowanAI.")
                    TB(t: "Liability", b: "Rakita Studios LLC is not liable for outcomes of decisions made using RowanAI suggestions.")
                    Text("Questions? legal@rakitastudios.com").font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                    Spacer().frame(height: 40)
                }
                .padding(SP.xl)
            }
            .rwBG()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.foregroundColor(.rwAccent) } }
        }
    }
}

struct TB: View {
    let t: String; let b: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(t).font(RWF.head(14)).foregroundColor(.rwTextPrimary)
            Text(b).font(RWF.body(13)).foregroundColor(.rwTextSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(SP.md).background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
    }
}

// MARK: - Relationship Status (Smart Onboarding)

struct RelationshipStatusView: View {
    @Binding var user: RWUser
    let next: () -> Void
    @State private var on = false

    var body: some View {
        VStack(spacing: 0) {
            OBHead(step: "Your Situation",
                   title: "Are you currently\nin a relationship?",
                   sub: "Rowan branches into different coaching depending on where you are.")
                .opacity(on ? 1 : 0)
            Spacer().frame(height: 32)
            VStack(spacing: 12) {
                ForEach(RelationshipStatus.allCases) { status in
                    RSCard(status: status, selected: user.relationshipStatus == status) {
                        user.relationshipStatus = status
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .opacity(on ? 1 : 0)
                }
            }
            .padding(.horizontal, SP.xl)
            Spacer()
            RWButton("Continue", icon: "arrow.right") { next() }
                .padding(.horizontal, SP.xl).padding(.bottom, 44)
                .opacity(on ? 1 : 0)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { on = true } }
    }
}

private struct RSCard: View {
    let status: RelationshipStatus
    let selected: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: status.icon)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(selected ? .white : status.color)
                    .frame(width: 52, height: 52)
                    .background(selected ? status.color : status.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                VStack(alignment: .leading, spacing: 4) {
                    Text(status.displayLabel).font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                    Text(status.subLabel).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(status.color).font(.system(size: 20, design: .rounded))
                }
            }
            .padding(SP.lg)
            .background(selected ? status.color.opacity(0.08) : Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl)
                .stroke(selected ? status.color.opacity(0.4) : Color.rwBorder,
                        lineWidth: selected ? 1.5 : 1))
            .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Partner Name

struct PartnerNameView: View {
    @Binding var user: RWUser
    let next: () -> Void
    @State private var name: String = ""
    @State private var on = false
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(spacing: 0) {
            OBHead(step: "Partner",
                   title: "What's your\npartner's first name?",
                   sub: "Cyrano uses this to personalise relationship coaching.")
                .opacity(on ? 1 : 0)
            Spacer().frame(height: 40)
            TextField("", text: $name,
                      prompt: Text("First name").foregroundColor(.rwTextMuted))
                .font(RWF.head(20)).foregroundColor(.rwTextPrimary)
                .padding(SP.lg).background(Color.rwCard)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg)
                    .stroke(focused ? Color.rwGold.opacity(0.5) : Color.rwBorder, lineWidth: 1))
                .focused($focused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .padding(.horizontal, SP.xl).opacity(on ? 1 : 0)
            Spacer()
            RWButton("Continue", icon: "arrow.right") {
                user.partnerName = trimmed.isEmpty ? nil : trimmed
                next()
            }
            .disabled(trimmed.isEmpty)
            .opacity(trimmed.isEmpty ? 0.5 : 1)
            .padding(.horizontal, SP.xl).padding(.bottom, 44)
            .opacity(on ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { on = true }
            if let existing = user.partnerName { name = existing }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focused = true }
        }
    }
}

// MARK: - Relationship Duration

struct RelationshipDurationView: View {
    @Binding var user: RWUser
    let next: () -> Void
    @State private var on = false

    var body: some View {
        VStack(spacing: 0) {
            OBHead(step: "Together",
                   title: "How long have you\ntwo been together?",
                   sub: "Calibrates the rituals and tools Cyrano shows you.")
                .opacity(on ? 1 : 0)
            Spacer().frame(height: 32)
            VStack(spacing: 10) {
                ForEach(RelationshipDuration.allCases) { d in
                    let selected = user.relationshipDuration == d
                    Button {
                        user.relationshipDuration = d
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(selected ? .white : .rwGold)
                                .frame(width: 44, height: 44)
                                .background(selected ? Color.rwGold : Color.rwGold.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: RR.md))
                            Text(d.rawValue).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.rwGold).font(.system(size: 18, design: .rounded))
                            }
                        }
                        .padding(SP.md)
                        .background(selected ? Color.rwGold.opacity(0.08) : Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                        .overlay(RoundedRectangle(cornerRadius: RR.xl)
                            .stroke(selected ? Color.rwGold.opacity(0.4) : Color.rwBorder,
                                    lineWidth: selected ? 1.5 : 1))
                    }
                    .buttonStyle(SBS()).opacity(on ? 1 : 0)
                }
            }
            .padding(.horizontal, SP.xl)
            Spacer()
            RWButton("Continue", icon: "arrow.right") { next() }
                .disabled(user.relationshipDuration == nil)
                .opacity(user.relationshipDuration == nil ? 0.5 : 1)
                .padding(.horizontal, SP.xl).padding(.bottom, 44)
                .opacity(on ? 1 : 0)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { on = true } }
    }
}

// MARK: - Relationship Goals (multi-select)

struct RelationshipGoalsView: View {
    @Binding var user: RWUser
    let next: () -> Void
    @State private var on = false

    var body: some View {
        VStack(spacing: 0) {
            OBHead(step: "Together",
                   title: "What do you want\nto work on together?",
                   sub: "Pick what feels true. You can change this later.")
                .opacity(on ? 1 : 0)
            Spacer().frame(height: 24)
            VStack(spacing: 10) {
                ForEach(RelationshipGoal.allCases) { goal in
                    let selected = user.relationshipGoals.contains(goal)
                    Button {
                        if selected {
                            user.relationshipGoals.removeAll { $0 == goal }
                        } else {
                            user.relationshipGoals.append(goal)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: goal.icon)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(selected ? .white : .rwGold)
                                .frame(width: 46, height: 46)
                                .background(selected ? Color.rwGold : Color.rwGold.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: RR.md))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(goal.rawValue).font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                                Text(goal.subtitle).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.rwGold).font(.system(size: 20, design: .rounded))
                            }
                        }
                        .padding(SP.md)
                        .background(selected ? Color.rwGold.opacity(0.06) : Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                        .overlay(RoundedRectangle(cornerRadius: RR.xl)
                            .stroke(selected ? Color.rwGold.opacity(0.4) : Color.rwBorder,
                                    lineWidth: selected ? 1.5 : 1))
                    }
                    .buttonStyle(SBS()).opacity(on ? 1 : 0)
                }
            }
            .padding(.horizontal, SP.xl)
            Spacer()
            RWButton("Continue", icon: "arrow.right") { next() }
                .disabled(user.relationshipGoals.isEmpty)
                .opacity(user.relationshipGoals.isEmpty ? 0.5 : 1)
                .padding(.horizontal, SP.xl).padding(.bottom, 44)
                .opacity(on ? 1 : 0)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { on = true } }
    }
}

// MARK: - Partner Invite (6-digit pairing code)

struct PartnerInviteView: View {
    @Binding var user: RWUser
    let next: () -> Void

    @State private var stage: Stage = .ask
    @State private var code: String = ""
    @State private var copied = false
    @State private var on = false

    enum Stage { case ask, code }

    private var partnerLabel: String { user.partnerName ?? "your partner" }

    var body: some View {
        VStack(spacing: 0) {
            switch stage {
            case .ask:  ask
            case .code: codeView
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { on = true } }
    }

    private var ask: some View {
        VStack(spacing: 0) {
            OBHead(step: "Together",
                   title: "Want to invite\n\(partnerLabel)?",
                   sub: "When you both join, Rowan unlocks shared rituals, mood sync, and the Couple Chemistry Report.")
                .opacity(on ? 1 : 0)
            Spacer().frame(height: 32)
            VStack(spacing: 12) {
                Button {
                    let generated = String(format: "%06d", Int.random(in: 0...999_999))
                    code = generated
                    user.partnerInviteCode = generated
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation { stage = .code }
                } label: {
                    inviteOption(icon: "envelope.fill",
                                 title: "Yes — invite them",
                                 sub: "Generate a 6-digit code to share",
                                 tinted: true)
                }
                .buttonStyle(SBS())

                Button {
                    user.partnerInviteCode = nil
                    next()
                } label: {
                    inviteOption(icon: "person.fill",
                                 title: "Skip for now",
                                 sub: "You can invite them anytime in Settings",
                                 tinted: false)
                }
                .buttonStyle(SBS())
            }
            .padding(.horizontal, SP.xl)
            .opacity(on ? 1 : 0)
            Spacer()
        }
    }

    private func inviteOption(icon: String, title: String, sub: String, tinted: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(tinted ? .white : .rwTextSecondary)
                .frame(width: 52, height: 52)
                .background(tinted ? Color.rwGold : Color.rwSurface)
                .clipShape(RoundedRectangle(cornerRadius: RR.md))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                Text(sub).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
        }
        .padding(SP.lg).background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
        .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
    }

    private var codeView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 22) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundColor(.rwGold)
                    .frame(width: 96, height: 96)
                    .background(Color.rwGold.opacity(0.12))
                    .clipShape(Circle())
                VStack(spacing: 6) {
                    Text("Share this code with").font(RWF.body()).foregroundColor(.rwTextSecondary)
                    Text(partnerLabel).font(RWF.title(22)).foregroundColor(.rwTextPrimary)
                }
                Text(code)
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .tracking(8)
                    .foregroundColor(.rwTextPrimary)
                    .padding(.horizontal, SP.xl).padding(.vertical, SP.lg)
                    .background(Color.rwCard)
                    .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                    .overlay(RoundedRectangle(cornerRadius: RR.lg)
                        .stroke(Color.rwGold.opacity(0.3), lineWidth: 1.5))
                Button {
                    UIPasteboard.general.string = code
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy code",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(RWF.med(14)).foregroundColor(.rwGold)
                }
                Text("They'll enter this code during their own onboarding to pair your accounts.")
                    .font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                    .multilineTextAlignment(.center).padding(.horizontal, SP.xl)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            RWButton("Continue", icon: "arrow.right") { next() }
                .padding(.horizontal, SP.xl).padding(.bottom, 44)
        }
    }
}
