import SwiftUI

// MARK: - Hard Conversation View

struct HardConversationView: View {
    let onBack: () -> Void
    @State private var step: HCStep = .intro
    @State private var emotion = ""
    @State private var action = ""
    @State private var need = ""
    @State private var context = ""
    @State private var cyranoRefinement = ""
    @State private var isLoading = false
    @State private var partnerStore = PartnerStore.shared
    @State private var shared = false
    @FocusState private var focused: HCFocus?

    enum HCStep { case intro, build, refine, ready }
    enum HCFocus { case emotion, action, need, context }

    let emotions = ["Hurt", "Anxious", "Disconnected", "Frustrated", "Overwhelmed",
                    "Unappreciated", "Lonely", "Confused", "Scared", "Unseen"]

    var fullStatement: String {
        "I feel \(emotion) when \(action) happens, and I need \(need)."
    }

    var isComplete: Bool {
        !emotion.isEmpty && !action.isEmpty && !need.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.rwTextPrimary).frame(width: 36, height: 36)
                        .background(Color.rwSurface).clipShape(Circle())
                }
                Spacer()
                Text("Hard Conversation").font(RWF.head()).foregroundColor(.rwTextPrimary)
                Spacer()
                Spacer().frame(width: 36)
            }
            .padding(.horizontal, SP.lg).padding(.vertical, 14)
            RWLine()

            switch step {
            case .intro:  introView
            case .build:  buildView
            case .refine: refineView
            case .ready:  readyView
            }
        }
        .rwBG()
    }

    // MARK: - Intro

    var introView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.xl) {
                VStack(spacing: 16) {
                    Text("💬").font(.system(size: 52)).padding(.top, 20)
                    Text("Let's say it\nthe right way.").font(RWF.display(28)).foregroundColor(.rwTextPrimary)
                        .multilineTextAlignment(.center)
                    Text("Hard conversations go better when you know what you actually feel and need — before you start talking.")
                        .font(RWF.body()).foregroundColor(.rwTextSecondary).multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    HCPrinciple(icon: "1.circle.fill", color: Color(hex: "E8356D"),
                        title: "One issue at a time",
                        sub: "No bringing up old arguments. Just this one thing.")
                    HCPrinciple(icon: "2.circle.fill", color: Color(hex: "5B8DEF"),
                        title: "Feelings, not accusations",
                        sub: "\"I feel\" is always stronger than \"You always\".")
                    HCPrinciple(icon: "3.circle.fill", color: Color(hex: "00BFB3"),
                        title: "Name what you need",
                        sub: "Most arguments happen because the need stays unspoken.")
                }

                RWButton("I'm Ready", icon: "arrow.right") {
                    withAnimation { step = .build }
                }
                .padding(.horizontal, SP.xl).padding(.bottom, 48)
            }
            .padding(.horizontal, SP.lg)
        }
    }

    // MARK: - Build

    var buildView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SP.xl) {

                // Kitchen sinking warning
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13)).foregroundColor(Color(hex: "F59E0B"))
                    Text("Stay focused on one thing. No old arguments, no other issues — just this.")
                        .font(RWF.cap(12)).foregroundColor(Color(hex: "F59E0B"))
                }
                .padding(SP.md).background(Color(hex: "F59E0B").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color(hex: "F59E0B").opacity(0.2), lineWidth: 1))

                // Live preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your statement").font(RWF.cap()).foregroundColor(.rwTextMuted)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 6) {
                            Text("I feel").font(RWF.body()).foregroundColor(.rwTextMuted)
                            Text(emotion.isEmpty ? "___________" : emotion.lowercased())
                                .font(RWF.med()).foregroundColor(emotion.isEmpty ? .rwTextMuted : Color(hex: "E8356D"))
                        }
                        HStack(alignment: .top, spacing: 6) {
                            Text("when").font(RWF.body()).foregroundColor(.rwTextMuted)
                            Text(action.isEmpty ? "___________" : action.lowercased())
                                .font(RWF.med()).foregroundColor(action.isEmpty ? .rwTextMuted : Color(hex: "5B8DEF"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(alignment: .top, spacing: 6) {
                            Text("happens, and I need").font(RWF.body()).foregroundColor(.rwTextMuted)
                            Text(need.isEmpty ? "___________" : need.lowercased())
                                .font(RWF.med()).foregroundColor(need.isEmpty ? .rwTextMuted : Color(hex: "00BFB3"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(".").font(RWF.body()).foregroundColor(.rwTextMuted)
                    }
                    .padding(SP.lg).background(Color.rwSurface)
                    .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                    .animation(.spring(response: 0.3), value: emotion + action + need)
                }

                // Emotion picker
                VStack(alignment: .leading, spacing: 10) {
                    Label("I feel...", systemImage: "heart.fill")
                        .font(RWF.cap()).foregroundColor(Color(hex: "E8356D"))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(emotions, id: \.self) { e in
                                Button { emotion = emotion == e ? "" : e } label: {
                                    Text(e).font(RWF.cap(12))
                                        .foregroundColor(emotion == e ? .white : .rwTextSecondary)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(emotion == e ? Color(hex: "E8356D") : Color.rwSurface)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(SBS())
                            }
                        }
                    }
                    // Custom emotion
                    TextField("", text: $emotion, prompt: Text("Or type your own...").foregroundColor(.rwTextMuted))
                        .font(RWF.body()).foregroundColor(.rwTextPrimary)
                        .padding(SP.md).background(Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                        .focused($focused, equals: .emotion)
                }

                // Action
                VStack(alignment: .leading, spacing: 8) {
                    Label("When...", systemImage: "arrow.right.circle.fill")
                        .font(RWF.cap()).foregroundColor(Color(hex: "5B8DEF"))
                    Text("Describe the specific behaviour — not the person. What happens, not who they are.")
                        .font(RWF.cap(11)).foregroundColor(.rwTextMuted)
                    TextField("", text: $action, prompt: Text("e.g. we go days without real conversation").foregroundColor(.rwTextMuted))
                        .font(RWF.body()).foregroundColor(.rwTextPrimary)
                        .padding(SP.md).background(Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                        .focused($focused, equals: .action)
                }

                // Need
                VStack(alignment: .leading, spacing: 8) {
                    Label("And I need...", systemImage: "checkmark.circle.fill")
                        .font(RWF.cap()).foregroundColor(Color(hex: "00BFB3"))
                    Text("What would actually help? Be specific. This is the part most people skip.")
                        .font(RWF.cap(11)).foregroundColor(.rwTextMuted)
                    TextField("", text: $need, prompt: Text("e.g. 30 minutes together without phones").foregroundColor(.rwTextMuted))
                        .font(RWF.body()).foregroundColor(.rwTextPrimary)
                        .padding(SP.md).background(Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                        .focused($focused, equals: .need)
                }

                // Optional context
                VStack(alignment: .leading, spacing: 8) {
                    Label("Extra context for Cyrano (optional)", systemImage: "note.text")
                        .font(RWF.cap()).foregroundColor(.rwTextMuted)
                    TextField("", text: $context, prompt: Text("Anything that helps Cyrano understand the situation...").foregroundColor(.rwTextMuted))
                        .font(RWF.body()).foregroundColor(.rwTextPrimary)
                        .padding(SP.md).background(Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                        .focused($focused, equals: .context)
                }

                RWButton(isLoading ? "Cyrano is reviewing..." : "Get Cyrano's Help", icon: isLoading ? nil : "sparkles") {
                    focused = nil
                    Task { await refine() }
                }
                .disabled(!isComplete || isLoading)
                .opacity(isComplete ? 1 : 0.5)
                .padding(.bottom, 48)
            }
            .padding(.horizontal, SP.lg).padding(.top, 12)
        }
        .hideKB()
    }

    // MARK: - Refine

    var refineView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                // Original
                VStack(alignment: .leading, spacing: 8) {
                    Label("Your statement", systemImage: "person.fill")
                        .font(RWF.cap()).foregroundColor(.rwTextMuted)
                    Text(fullStatement).font(RWF.body()).foregroundColor(.rwTextPrimary)
                        .fixedSize(horizontal: false, vertical: true).lineSpacing(4)
                        .padding(SP.md).background(Color.rwSurface)
                        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                }
                .padding(.top, 8)

                // Cyrano's refinement
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        GlowDot()
                        Text("Cyrano's thoughts").font(RWF.micro()).foregroundColor(.rwAccent).tracking(1.5)
                    }
                    if isLoading {
                        RWLoading(msg: "Reviewing your statement...").frame(height: 80)
                    } else {
                        Text(cyranoRefinement).font(RWF.body()).foregroundColor(.rwTextPrimary)
                            .fixedSize(horizontal: false, vertical: true).lineSpacing(4)
                    }
                }
                .padding(SP.lg).background(Color.rwCard)
                .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
                .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)

                if !isLoading {
                    VStack(spacing: 10) {
                        RWButton("I'm Ready to Have This Conversation", icon: "checkmark") {
                            withAnimation { step = .ready }
                        }
                        Button("Edit my statement") { withAnimation { step = .build } }
                            .font(RWF.cap()).foregroundColor(.rwTextMuted)
                    }
                }
                Spacer().frame(height: 60)
            }
            .padding(.horizontal, SP.lg)
        }
    }

    // MARK: - Ready

    var readyView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.xl) {
                VStack(spacing: 12) {
                    Text("✅").font(.system(size: 52)).padding(.top, 20)
                    Text("You're ready.").font(RWF.display(28)).foregroundColor(.rwTextPrimary)
                    Text("You know what you feel and what you need. That's most of the battle.")
                        .font(RWF.body()).foregroundColor(.rwTextSecondary).multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Final statement
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your statement").font(RWF.cap()).foregroundColor(.rwTextMuted)
                    Text(fullStatement).font(RWF.body(17)).foregroundColor(.rwTextPrimary)
                        .fixedSize(horizontal: false, vertical: true).lineSpacing(5)
                        .padding(SP.lg).background(Color(hex: "00BFB3").opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color(hex: "00BFB3").opacity(0.2), lineWidth: 1))
                }

                // Reminders before the conversation
                RWCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Before you start").font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                        HCReminder(icon: "clock.fill", color: Color(hex: "5B8DEF"),
                            text: "Pick a calm moment. Not when either of you is tired, hungry, or already stressed.")
                        HCReminder(icon: "nosign", color: Color(hex: "E8356D"),
                            text: "No old arguments. If it comes up, say: \"Let's stay focused on this one thing.\"")
                        HCReminder(icon: "ear.fill", color: Color(hex: "00BFB3"),
                            text: "After you say your piece — listen. Their response matters.")
                        HCReminder(icon: "heart.fill", color: Color(hex: "F59E0B"),
                            text: "Start with: \"I want to talk about something important to me, and I want us to get through it together.\"")
                    }
                }

                VStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = fullStatement
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label("Copy My Statement", systemImage: "doc.on.doc")
                            .font(RWF.med()).foregroundColor(.rwAccent)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.rwAccent.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: RR.pill))
                    }
                    .buttonStyle(SBS())

                    if partnerStore.isConnected {
                        Button {
                            // Share with partner (store locally - they'll see it in their app)
                            UserDefaults.standard.set(fullStatement, forKey: "partner_message_\(Date().timeIntervalSince1970)")
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            withAnimation { shared = true }
                        } label: {
                            Label(shared ? "Sent to \(partnerStore.partnerName)" : "Send to \(partnerStore.partnerName)",
                                systemImage: shared ? "checkmark.circle.fill" : "paperplane.fill")
                                .font(RWF.med())
                                .foregroundColor(shared ? .rwSuccess : .white)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(shared ? Color.rwSuccess.opacity(0.1) : Color(hex: "0D0D0D"))
                                .clipShape(RoundedRectangle(cornerRadius: RR.pill))
                        }
                        .buttonStyle(SBS()).disabled(shared)
                    }

                    Button("Start Over") { withAnimation { step = .intro; emotion = ""; action = ""; need = ""; context = ""; cyranoRefinement = ""; shared = false } }
                        .font(RWF.cap()).foregroundColor(.rwTextMuted)
                }
                .padding(.bottom, 48)
            }
            .padding(.horizontal, SP.lg)
        }
    }

    func refine() async {
        isLoading = true
        withAnimation { step = .refine }
        let rel = RelationshipStore.shared.relationship
        let partner = rel?.partnerName ?? "their partner"
        let system = """
        You are Cyrano, a relationship communication coach. Review this person's prepared statement for a hard conversation.
        Partner's name: \(partner)
        Principles: Gottman method, I-statements, one issue at a time, no contempt or criticism of character.
        Your job: validate what they've done well, gently flag anything that might come across as blaming or attacking, and suggest one small tweak if needed.
        Be warm and brief — 3-4 sentences. End with encouragement.
        """
        let user = "Statement: \"\(fullStatement)\"\(context.isEmpty ? "" : "\nContext: \(context)")"
        do {
            cyranoRefinement = try await Claude.shared.send(system: system, user: user, max: 250)
        } catch {
            cyranoRefinement = "Your statement is clear and focuses on your feelings and needs — that's exactly right. Go into this conversation with the intention of being heard and of hearing them back."
        }
        isLoading = false
    }
}

struct HCPrinciple: View {
    let icon: String; let color: Color; let title: String; let sub: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                .foregroundColor(color).frame(width: 36, height: 36)
                .background(color.opacity(0.1)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(RWF.head(14)).foregroundColor(.rwTextPrimary)
                Text(sub).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SP.md).background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
    }
}

struct HCReminder: View {
    let icon: String; let color: Color; let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                .foregroundColor(color).frame(width: 24)
            Text(text).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
