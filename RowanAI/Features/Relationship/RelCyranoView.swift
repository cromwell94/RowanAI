import SwiftUI

// MARK: - Relationship Cyrano View

struct RelCyranoView: View {
    @State private var mode: RCMode = .menu
    @State private var partnerStore = PartnerStore.shared

    enum RCMode { case menu, vent, ask, communicate, hard }

    var body: some View {
        switch mode {
        case .menu:        menuView
        case .vent:        VentView { mode = .menu }
        case .ask:         IsThisNormalView { mode = .menu }
        case .communicate: CommunicateView { mode = .menu }
        case .hard:        HardConversationView { mode = .menu }
        }
    }

    var menuView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cyrano is here.").font(RWF.display(28)).foregroundColor(.rwTextPrimary)
                    Text("Whatever you're going through — you can say it here.")
                        .font(RWF.body()).foregroundColor(.rwTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 14) {
                    RelFeatureCard(
                        icon: "cloud.rain.fill",
                        title: "Just Vent",
                        description: "Get it all out. Cyrano listens first, asks questions gently, never judges.",
                        color: Color(hex: "9B59B6"),
                        tag: "Private"
                    ) { withAnimation { mode = .vent } }

                    RelFeatureCard(
                        icon: "questionmark.bubble.fill",
                        title: "Is This Normal?",
                        description: "Ask anything about your relationship. Cyrano answers honestly — validating what's fine, flagging what's not.",
                        color: Color(hex: "5B8DEF"),
                        tag: "Honest"
                    ) { withAnimation { mode = .ask } }

                    RelFeatureCard(
                        icon: "text.bubble.fill",
                        title: "Help Me Say This",
                        description: "Practice a hard conversation. Cyrano helps you find the right words for difficult moments.",
                        color: Color(hex: "E8356D"),
                        tag: "Practice"
                    ) { withAnimation { mode = .communicate } }

                    RelFeatureCard(
                        icon: "exclamationmark.bubble.fill",
                        title: "I Need to Talk About Something",
                        description: "A structured template that helps you say something hard — clearly, kindly, and without bringing up old arguments.",
                        color: Color(hex: "F59E0B"),
                        tag: "Hard Conversations"
                    ) { withAnimation { mode = .hard } }
                }

                // Crisis always visible
                CrisisQuickAccess()

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg).padding(.top, 16)
        }
    }
}

struct RelFeatureCard: View {
    let icon: String; let title: String; let description: String
    let color: Color; let tag: String; let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white).frame(width: 52, height: 52)
                    .background(color).clipShape(RoundedRectangle(cornerRadius: RR.md))
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title).font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                        Text(tag).font(RWF.micro()).foregroundColor(color)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(color.opacity(0.1)).clipShape(Capsule())
                    }
                    Text(description).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
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
            .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Just Vent

struct VentView: View {
    let onBack: () -> Void
    @State private var store = RelationshipStore.shared
    @State private var ventText = ""
    @State private var mood: Vent.Mood = .mixed
    @State private var response = ""
    @State private var isLoading = false
    @State private var showResponse = false
    @State private var saved = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.rwTextPrimary).frame(width: 36, height: 36)
                        .background(Color.rwSurface).clipShape(Circle())
                }
                Spacer()
                Text("Just Vent").font(RWF.head()).foregroundColor(.rwTextPrimary)
                Spacer()
                Spacer().frame(width: 36)
            }
            .padding(.horizontal, SP.lg).padding(.vertical, 14)

            RWLine()

            if showResponse {
                responseView
            } else {
                inputView
            }
        }
        .rwBG()
    }

    var inputView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SP.lg) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What's on your mind?").font(RWF.title(22)).foregroundColor(.rwTextPrimary)
                        Text("This is private. Say exactly what you're feeling. Cyrano listens before it responds.")
                            .font(RWF.body()).foregroundColor(.rwTextSecondary)
                    }
                    .padding(.top, 8)

                    // Mood selector
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How are you feeling?").font(RWF.cap()).foregroundColor(.rwTextMuted)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Vent.Mood.allCases, id: \.rawValue) { m in
                                    Button { mood = m } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: m.icon).font(.system(size: 11, weight: .semibold, design: .rounded))
                                            Text(m.rawValue).font(RWF.cap(12))
                                        }
                                        .foregroundColor(mood == m ? .white : .rwTextSecondary)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(mood == m ? m.color : Color.rwSurface)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(SBS())
                                }
                            }
                        }
                    }

                    // Text area
                    ZStack(alignment: .topLeading) {
                        if ventText.isEmpty {
                            Text("Start typing... there's no right way to do this.")
                                .font(RWF.body()).foregroundColor(.rwTextMuted)
                                .padding(.horizontal, 4).padding(.vertical, 12).allowsHitTesting(false)
                        }
                        TextEditor(text: $ventText)
                            .font(RWF.body()).foregroundColor(.rwTextPrimary)
                            .frame(minHeight: 200).scrollContentBackground(.hidden).focused($focused)
                    }
                    .padding(SP.md).background(Color.rwCard)
                    .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                    .overlay(RoundedRectangle(cornerRadius: RR.xl)
                        .stroke(focused ? Color(hex: "9B59B6").opacity(0.3) : Color.rwBorder, lineWidth: 1))
                    .onAppear { focused = true }

                    // Disclaimer
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill").font(.system(size: 11, design: .rounded))
                        Text("This is private. Cyrano won't judge, minimize, or give unsolicited advice.")
                            .font(.system(size: 11, design: .rounded))
                    }
                    .foregroundColor(.rwTextMuted)

                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, SP.lg)
            }

            // Send
            RWLine()
            RWButton(isLoading ? "Cyrano is listening..." : "Send to Cyrano", icon: isLoading ? nil : "paperplane.fill") {
                focused = false
                Task { await sendVent() }
            }
            .disabled(ventText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            .opacity(ventText.isEmpty ? 0.5 : 1)
            .padding(.horizontal, SP.lg).padding(.vertical, 14)
        }
    }

    var responseView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                // What you said
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: mood.icon).foregroundColor(mood.color)
                        Text("You said").font(RWF.cap()).foregroundColor(.rwTextMuted)
                    }
                    Text(ventText).font(RWF.body()).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(SP.md).background(Color.rwSurface)
                .clipShape(RoundedRectangle(cornerRadius: RR.xl))

                // Cyrano response
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        GlowDot()
                        Text("Cyrano").font(RWF.micro()).foregroundColor(.rwAccent).tracking(1.5)
                    }
                    Text(response).font(RWF.body()).foregroundColor(.rwTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(SP.lg).background(Color.rwCard)
                .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
                .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)

                // Crisis resources
                CrisisQuickAccess()

                HStack(spacing: 12) {
                    RWButton(saved ? "Saved" : "Save to Journal", icon: saved ? "checkmark" : "book.fill", style: .secondary) {
                        let vent = Vent(content: ventText, cyranoResponse: response, mood: mood)
                        store.update { $0.vents.insert(vent, at: 0) }
                        saved = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .disabled(saved)

                    RWButton("Vent Again", icon: "arrow.counterclockwise", style: .ghost) {
                        withAnimation { showResponse = false; ventText = ""; response = ""; saved = false }
                    }
                }

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg).padding(.top, 16)
        }
    }

    func sendVent() async {
        isLoading = true
        let system = """
        You are Cyrano in relationship support mode. Someone is venting to you.
        Your role: Listen. Validate. Reflect back what you heard. Ask ONE gentle question at the end if appropriate.
        Rules:
        - Never minimize feelings
        - Never give unsolicited advice unless they ask
        - Never take sides against their partner unless there are clear safety concerns
        - If you detect signs of abuse, coercive control, or danger — acknowledge their feelings first, then gently provide safety resources
        - Be warm, human, not clinical
        - 3-5 sentences max
        - End with one gentle, open question OR simply affirm that they don't have to have it all figured out
        If crisis keywords are present: acknowledge feelings, provide 988 and National DV Hotline (1-800-799-7233).
        """
        let rel = RelationshipStore.shared.relationship
        let context = rel.map { "They are in a relationship with \($0.partnerName)." } ?? ""
        do {
            response = try await Claude.shared.send(
                system: system,
                user: "Mood: \(mood.rawValue)\n\(context)\nWhat they said: \(ventText)",
                max: 300)
            withAnimation { showResponse = true }
        } catch {
            response = "Something went wrong. Please try again."
            withAnimation { showResponse = true }
        }
        isLoading = false
    }
}

// MARK: - Is This Normal?

struct IsThisNormalView: View {
    let onBack: () -> Void
    @State private var question = ""
    @State private var answer = ""
    @State private var isLoading = false
    @State private var showAnswer = false
    @FocusState private var focused: Bool

    let prompts = [
        "Is it normal to still find other people attractive?",
        "Is it normal to need space sometimes?",
        "Is it normal to argue about small things?",
        "Is it okay if they check my phone?",
        "Is it normal to feel less excited after a few months?",
        "Is it normal for them to get angry when I see friends?",
        "Is it okay that they don't like my friends?",
        "Is it normal to feel like I'm losing myself?"
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.rwTextPrimary).frame(width: 36, height: 36)
                        .background(Color.rwSurface).clipShape(Circle())
                }
                Spacer()
                Text("Is This Normal?").font(RWF.head()).foregroundColor(.rwTextPrimary)
                Spacer()
                Spacer().frame(width: 36)
            }
            .padding(.horizontal, SP.lg).padding(.vertical, 14)
            RWLine()

            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    if !showAnswer {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ask anything.").font(RWF.title(22)).foregroundColor(.rwTextPrimary)
                            Text("Cyrano answers honestly — validating what's genuinely fine, and flagging what deserves attention.")
                                .font(RWF.body()).foregroundColor(.rwTextSecondary)
                        }
                        .padding(.top, 8)

                        // Quick prompts
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Common questions").font(RWF.cap()).foregroundColor(.rwTextMuted)
                            ForEach(prompts, id: \.self) { p in
                                Button {
                                    question = p
                                    Task { await ask() }
                                } label: {
                                    HStack {
                                        Text(p).font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.rwTextMuted)
                                    }
                                    .padding(SP.md).background(Color.rwCard)
                                    .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                                    .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                                }
                                .buttonStyle(SBS())
                            }
                        }
                    } else {
                        // Question
                        VStack(alignment: .leading, spacing: 6) {
                            Text("You asked").font(RWF.cap()).foregroundColor(.rwTextMuted)
                            Text(question).font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                        }
                        .padding(SP.md).background(Color.rwSurface)
                        .clipShape(RoundedRectangle(cornerRadius: RR.xl))

                        if isLoading {
                            RWLoading(msg: "Cyrano is thinking...")
                                .frame(height: 120)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    GlowDot()
                                    Text("Cyrano").font(RWF.micro()).foregroundColor(.rwAccent).tracking(1.5)
                                }
                                Text(answer).font(RWF.body()).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(SP.lg).background(Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
                            .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)

                            CrisisQuickAccess()

                            Button {
                                withAnimation { showAnswer = false; question = ""; answer = "" }
                            } label: {
                                Label("Ask something else", systemImage: "arrow.counterclockwise")
                                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                            }
                        }
                    }
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, SP.lg).padding(.top, 12)
            }

            if !showAnswer {
                RWLine()
                HStack(spacing: 12) {
                    TextField("", text: $question, prompt: Text("Type your question...").foregroundColor(.rwTextMuted))
                        .font(RWF.body()).foregroundColor(.rwTextPrimary).focused($focused)
                        .onSubmit { Task { await ask() } }
                    Button { Task { await ask() } } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 28, design: .rounded))
                            .foregroundColor(question.isEmpty ? .rwTextMuted : .rwAccent)
                    }
                    .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty).buttonStyle(SBS())
                }
                .padding(.horizontal, SP.lg).padding(.vertical, 14).background(Color.rwBackground)
            }
        }
        .rwBG()
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true } }
    }

    func ask() async {
        guard !question.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true; showAnswer = true
        let system = """
        You are Cyrano, a relationship coach. Someone asked "is this normal?" about their relationship.
        Answer honestly and directly:
        - If it IS normal and healthy: validate clearly and briefly explain why
        - If it's a YELLOW FLAG: acknowledge it might feel normal but explain why it deserves attention
        - If it's a RED FLAG or warning sign of abuse/control: be clear, compassionate, and provide resources
        Never minimize genuine concerns. Never catastrophize normal things.
        Safety note: If the question suggests coercive control, abuse, isolation, or danger — name it clearly and provide the National DV Hotline (1-800-799-7233) and 988.
        Be direct. 3-5 sentences. No hedging.
        """
        do {
            answer = try await Claude.shared.send(system: system, user: question, max: 300)
        } catch { answer = "Something went wrong. Please try again." }
        isLoading = false
    }
}

// MARK: - Communicate / Hard Conversations

struct CommunicateView: View {
    let onBack: () -> Void
    @State private var scenario = ""
    @State private var response = ""
    @State private var isLoading = false
    @FocusState private var focused: Bool

    let scenarios = [
        "I need more quality time together",
        "Something you said hurt me",
        "I feel like we've been disconnected lately",
        "I want to talk about where this is going",
        "I need more space sometimes",
        "I don't feel appreciated",
        "I'm not happy with how we handled that argument",
        "I want to talk about our future together"
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.rwTextPrimary).frame(width: 36, height: 36)
                        .background(Color.rwSurface).clipShape(Circle())
                }
                Spacer()
                Text("Help Me Say This").font(RWF.head()).foregroundColor(.rwTextPrimary)
                Spacer()
                Spacer().frame(width: 36)
            }
            .padding(.horizontal, SP.lg).padding(.vertical, 14)
            RWLine()

            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hard to say?").font(RWF.title(22)).foregroundColor(.rwTextPrimary)
                        Text("Tell Cyrano what you need to express and it will help you find the right words — kind but clear.")
                            .font(RWF.body()).foregroundColor(.rwTextSecondary)
                    }
                    .padding(.top, 8)

                    if response.isEmpty {
                        // Quick scenarios
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Common situations").font(RWF.cap()).foregroundColor(.rwTextMuted)
                            ForEach(scenarios, id: \.self) { s in
                                Button {
                                    scenario = s
                                    Task { await getSuggestion() }
                                } label: {
                                    HStack {
                                        Text(s).font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.rwTextMuted)
                                    }
                                    .padding(SP.md).background(Color.rwCard)
                                    .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                                    .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                                }
                                .buttonStyle(SBS())
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Topic").font(RWF.cap()).foregroundColor(.rwTextMuted)
                            Text(scenario).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                        }
                        .padding(SP.md).background(Color.rwSurface).clipShape(RoundedRectangle(cornerRadius: RR.xl))

                        if isLoading {
                            RWLoading(msg: "Finding the right words...")
                                .frame(height: 120)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    GlowDot()
                                    Text("Cyrano suggests").font(RWF.micro()).foregroundColor(.rwAccent).tracking(1.5)
                                }
                                Text(response).font(RWF.body()).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(SP.lg).background(Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
                            .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)

                            HStack(spacing: 10) {
                                Button { UIPasteboard.general.string = response } label: {
                                    Label("Copy", systemImage: "doc.on.doc").font(RWF.cap()).foregroundColor(.rwAccent)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Color.rwAccent.opacity(0.08)).clipShape(Capsule())
                                }
                                .buttonStyle(SBS())

                                Button { withAnimation { response = ""; scenario = "" } } label: {
                                    Label("Try another", systemImage: "arrow.counterclockwise")
                                        .font(RWF.cap()).foregroundColor(.rwTextMuted)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Color.rwSurface).clipShape(Capsule())
                                }
                                .buttonStyle(SBS())
                            }
                        }
                    }
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, SP.lg).padding(.top, 12)
            }

            if response.isEmpty {
                RWLine()
                HStack(spacing: 12) {
                    TextField("", text: $scenario, prompt: Text("Describe what you need to say...").foregroundColor(.rwTextMuted))
                        .font(RWF.body()).foregroundColor(.rwTextPrimary).focused($focused)
                        .onSubmit { Task { await getSuggestion() } }
                    Button { Task { await getSuggestion() } } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 28, design: .rounded))
                            .foregroundColor(scenario.isEmpty ? .rwTextMuted : .rwAccent)
                    }
                    .disabled(scenario.trimmingCharacters(in: .whitespaces).isEmpty).buttonStyle(SBS())
                }
                .padding(.horizontal, SP.lg).padding(.vertical, 14).background(Color.rwBackground)
            }
        }
        .rwBG()
    }

    func getSuggestion() async {
        guard !scenario.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        let rel = RelationshipStore.shared.relationship
        let partner = rel?.partnerName ?? "your partner"
        let system = """
        You are Cyrano, a relationship communication coach. Help someone say something difficult to their partner.
        Partner's name: \(partner)
        Principles (John Gottman based):
        - Use "I" statements not "you" accusations
        - Describe the behavior, not the person
        - Express the feeling, then the need
        - Be specific, not global ("always/never")
        - Keep it calm, clear, and kind
        - No contempt, no criticism of character
        Provide one natural-sounding way to say this. 3-5 sentences. Should sound like a real person talking, not a therapy textbook.
        """
        do {
            response = try await Claude.shared.send(system: system, user: "They need to say: \(scenario)", max: 300)
        } catch { response = "Something went wrong. Please try again." }
        isLoading = false
    }
}

// MARK: - Crisis Quick Access

struct CrisisQuickAccess: View {
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button { withAnimation { expanded.toggle() } } label: {
                HStack(spacing: 10) {
                    Image(systemName: "cross.circle.fill").font(.system(size: 16, design: .rounded)).foregroundColor(Color(hex: "E8356D"))
                    Text("Crisis & Support Resources").font(RWF.cap()).foregroundColor(.rwTextSecondary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.rwTextMuted)
                }
                .padding(SP.md).background(Color.rwSurface)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
            }
            .buttonStyle(SBS())

            if expanded {
                VStack(spacing: 8) {
                    CrisisRow(icon: "phone.fill", title: "988 Suicide & Crisis Lifeline", sub: "Call or text 988", url: "tel:988", color: Color(hex: "E8356D"))
                    CrisisRow(icon: "person.2.fill", title: "National DV Hotline", sub: "1-800-799-7233", url: "tel:18007997233", color: Color(hex: "5B8DEF"))
                    CrisisRow(icon: "message.fill", title: "Crisis Text Line", sub: "Text HOME to 741741", url: "sms:741741", color: Color(hex: "00BFB3"))
                }
                .padding(.horizontal, SP.sm).padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

struct CrisisRow: View {
    let icon: String; let title: String; let sub: String; let url: String; let color: Color
    var body: some View {
        // Crisis surface — never force-unwrap. If the URL is malformed for any
        // reason we render a non-tappable row so the user still sees the number
        // they can dial manually.
        Group {
            if let dest = URL(string: url) {
                Link(destination: dest) { rowContent }
                    .buttonStyle(SBS())
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(color).frame(width: 32, height: 32)
                .background(color.opacity(0.1)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(RWF.med(13)).foregroundColor(.rwTextPrimary)
                Text(sub).font(RWF.cap(11)).foregroundColor(.rwTextSecondary)
            }
            Spacer()
            Image(systemName: "arrow.up.right").font(.system(size: 11, design: .rounded)).foregroundColor(.rwTextMuted)
        }
        .padding(SP.sm).background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
    }
}
