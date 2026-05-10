import SwiftUI

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(AppState.self) var app
    @State private var tab = 0
    @State private var guide = false
    @State private var relStore = RelationshipStore.shared

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $tab) {
                ArchiveView()
                    .tabItem { Label("Archive", systemImage: tab == 0 ? "person.2.fill" : "person.2") }.tag(0)
                CyranoView()
                    .tabItem { Label("Cyrano", systemImage: "bubble.left.and.bubble.right.fill") }.tag(1)
                HomeView(tab: $tab)
                    .tabItem { Label("Home", systemImage: tab == 2 ? "house.fill" : "house") }.tag(2)
                DatePlannerView()
                    .tabItem { Label("Planner", systemImage: tab == 3 ? "map.fill" : "map") }.tag(3)
                DebriefListView()
                    .tabItem { Label("Journal", systemImage: tab == 4 ? "book.fill" : "book") }.tag(4)
                if relStore.isInRelationship {
                    RelationshipView()
                        .tabItem { Label("Relationship", systemImage: tab == 5 ? "heart.fill" : "heart") }.tag(5)
                    ProfileView()
                        .tabItem { Label("Profile", systemImage: tab == 6 ? "person.fill" : "person") }.tag(6)
                } else {
                    ProfileView()
                        .tabItem { Label("Profile", systemImage: tab == 5 ? "person.fill" : "person") }.tag(5)
                }
            }
            .tint(app.appMode.accentColor)

            // Guide button
            Button {
                guide = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                ZStack {
                    Circle().fill(Color.rwAccent.opacity(0.2)).frame(width: 64, height: 64)
                    Circle().fill(LinearGradient.accent).frame(width: 56, height: 56)
                        .shadow(color: Color.rwAccent.opacity(0.4), radius: 12, x: 0, y: 4)
                    VStack(spacing: 2) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundColor(.white)
                        Text("Guide").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .buttonStyle(SBS())
            .padding(.trailing, 20).padding(.bottom, 90)
        }
        .sheet(isPresented: $guide) {
            GuideSheet(open: $guide)
                .presentationDetents([.medium, .large])
                .presentationBackground(Color.rwSurface)
        }
    }
}

// MARK: - Home

struct HomeView: View {
    @Environment(AppState.self) var app
    @Binding var tab: Int
    @State private var on = false

    var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let n = AuthService.shared.currentUser?.name ?? ""
        let suf = n.isEmpty ? "" : ", \(n)"
        if h < 12 { return "Good morning\(suf)." }
        if h < 17 { return "Good afternoon\(suf)." }
        return "Good evening\(suf)."
    }

    let tips = [
        ("48-hour rule", "Follow up within 48 hours of matching. After that, response probability drops significantly."),
        ("Quality beats quantity", "5 deeply engaged matches convert better than 50 shallow ones. Prune your list weekly."),
        ("Ask, don't tell", "Questions create investment. Statements create boredom. Aim for more questions in early messages."),
        ("Best send times", "7-9pm on weeknights drives higher response rates than midday messages.")
    ]

    var tip: (String, String) { tips[Calendar.current.component(.day, from: Date()) % tips.count] }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(greeting).font(RWF.display(26)).foregroundColor(.rwTextPrimary)
                        Text("Here's what needs your attention today.").font(RWF.body()).foregroundColor(.rwTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .staggerAppear(0, appeared: on)

                    // Streak & skill card
                    StreakCard()
                        .staggerAppear(1, appeared: on)

                    // Dating / Relationship mode indicator
                    if RelationshipStore.shared.isInRelationship {
                        HStack(spacing: 10) {
                            Image(systemName: "heart.circle.fill")
                                .font(.system(size: 16, design: .rounded)).foregroundColor(Color(hex: "00BFB3"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Relationship Mode").font(RWF.head(14)).foregroundColor(.rwTextPrimary)
                                Text("You & \(RelationshipStore.shared.relationship?.partnerName ?? "")").font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                            }
                            Spacer()
                            Image(systemName: "heart.fill")
                                .font(.system(size: 20, design: .rounded))
                                .foregroundStyle(LinearGradient.accent)
                        }
                        .padding(SP.md).background(Color(hex: "00BFB3").opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color(hex: "00BFB3").opacity(0.2), lineWidth: 1))
                        .staggerAppear(2, appeared: on)
                    }

                    // Quick actions
                    RWSectionLabel("QUICK ACCESS")
                        .staggerAppear(2, appeared: on)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        QCard(icon: "bubble.left.and.bubble.right.fill", title: "Cyrano",  sub: "Craft your reply",    color: .rwAccent)        { tab = 1 }
                        QCard(icon: "doc.text.magnifyingglass",          title: "Debrief", sub: "Analyze a date",      color: Color(hex: "6B7FD7")) { tab = 4 }
                        QCard(icon: "person.2.fill",                     title: "Archive", sub: "Your connections",    color: Color(hex: "4CAF89")) { tab = 0 }
                        QCard(icon: "map.fill",                          title: "Planner", sub: "Find date venues",    color: .rwGold)           { tab = 3 }
                    }
                    .staggerAppear(3, appeared: on)

                    // Daily tip
                    RWCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                GlowDot()
                                Text("TODAY'S EDGE").font(RWF.micro()).foregroundColor(.rwAccent).tracking(1.5)
                            }
                            Text(tip.0).font(RWF.head()).foregroundColor(.rwTextPrimary)
                            Text(tip.1).font(RWF.body()).foregroundColor(.rwTextSecondary)
                        }
                    }
                    .staggerAppear(4, appeared: on)

                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, SP.lg).padding(.top, 20)
            }
            .rwBG()
            .navigationBarHidden(true)
        }
        .onAppear { on = true }
    }
}

struct ModeTab: View {
    let title: String; let icon: String; let active: Bool; let color: Color; let tap: () -> Void
    var body: some View {
        Button(action: tap) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(title).font(RWF.cap(13))
            }
            .foregroundColor(active ? .white : .rwTextMuted)
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(active ? color : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: RR.md))
        }
        .buttonStyle(SBS())
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: active)
    }
}

struct QCard: View {
    let icon: String; let title: String; let sub: String; let color: Color; let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundColor(color)
                    .frame(width: 44, height: 44).background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                    Text(sub).font(RWF.cap(11)).foregroundColor(.rwTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(SP.md)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
            .shadow(color: color.opacity(0.1), radius: 14, x: 0, y: 5)
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Profile

struct ProfileView: View {
    @Environment(AppState.self) var app
    @State private var aiOn = AISettings.shared.isEnabled
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showPaywall = false
    @State private var showLanguage = false
    @State private var tutorialsOn = TutorialManager.shared.tutorialsEnabled
    @State private var resetConfirmation = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    // Avatar
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(Color.rwAccent.opacity(0.15)).frame(width: 90, height: 90)
                            Text(String(AuthService.shared.currentUser?.name.prefix(1) ?? "R").uppercased())
                                .font(.system(size: 36, weight: .black, design: .rounded)).foregroundColor(.rwAccent)
                        }.padding(.top, 20)
                        HStack(spacing: 8) {
                            Text(AuthService.shared.currentUser?.name ?? "")
                                .font(RWF.title()).foregroundColor(.rwTextPrimary)
                            if StoreManager.shared.isPro {
                                Text("PRO").font(RWF.micro())
                                    .foregroundStyle(LinearGradient.accent)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.rwAccent.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        // Skill score mini
                        HStack(spacing: 6) {
                            Text("🔥 \(StreakManager.shared.currentStreak) day streak")
                                .font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                                .contentTransition(.numericText())
                            Text("·").foregroundColor(.rwTextMuted)
                            Text("\(StreakManager.shared.skillScore) pts")
                                .font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                        }
                    }



                    // AI Toggle
                    RWCard {
                        HStack(spacing: 14) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(aiOn ? .rwAccent : .rwTextMuted)
                                .frame(width: 44, height: 44)
                                .background(aiOn ? Color.rwAccent.opacity(0.12) : Color.rwBackground)
                                .clipShape(RoundedRectangle(cornerRadius: RR.md))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("AI Features").font(RWF.med()).foregroundColor(.rwTextPrimary)
                                Text(aiOn ? "Active — Cyrano is ready to coach you" : "Off — all data stays on device")
                                    .font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: $aiOn).tint(.rwAccent).labelsHidden()
                                .onChange(of: aiOn) { _, v in AISettings.shared.isEnabled = v }
                        }
                    }

                    // Settings
                    VStack(spacing: 0) {
                        PRow(icon: "globe", title: "Language") { showLanguage = true }
                        PRow(icon: "lock.shield.fill",  title: "Privacy & Security") { showPrivacy = true }
                        PRow(icon: "doc.text.fill",    title: "Terms & Privacy")   { showTerms = true }
                        PRow(icon: "cross.fill",        title: "Crisis Resources")  {}
                        PRow(icon: "crown.fill", title: StoreManager.shared.isPro ? "Rowan Pro — Active" : "Upgrade to Pro") {
                            showPaywall = true
                        }
                    }
                    .background(Color.rwCard)
                    .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                    .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))

                    // Tutorials — global toggle + reset all
                    VStack(spacing: 0) {
                        HStack(spacing: 14) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.rwAccent)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tutorials").font(RWF.body()).foregroundColor(.rwTextPrimary)
                                Text(tutorialsOn ? "Show on first visit to a feature" : "Off — tap ? on any screen to replay")
                                    .font(RWF.cap(11)).foregroundColor(.rwTextMuted)
                            }
                            Spacer()
                            Toggle("", isOn: $tutorialsOn)
                                .tint(.rwAccent).labelsHidden()
                                .onChange(of: tutorialsOn) { _, v in
                                    TutorialManager.shared.tutorialsEnabled = v
                                }
                        }
                        .padding(.horizontal, SP.lg).padding(.vertical, 14)
                        Divider().padding(.horizontal, SP.lg).background(Color.rwBorder)
                        Button { resetConfirmation = true } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(.rwAccent).frame(width: 30)
                                Text("Reset all tutorials").font(RWF.body()).foregroundColor(.rwTextPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.rwTextMuted)
                            }
                            .padding(.horizontal, SP.lg).padding(.vertical, 14)
                        }
                        .buttonStyle(SBS())
                    }
                    .background(Color.rwCard)
                    .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                    .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))

                    if !app.isInRelationship {

                    }

                    Text("Cyrano provides AI-generated coaching only — not professional relationship advice.")
                        .font(.system(size: 11, design: .rounded)).foregroundColor(.rwTextMuted).multilineTextAlignment(.center).padding(.horizontal, SP.xl)

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, SP.lg)
            }
            .rwBG()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showTerms) { TermsSheet() }
            .sheet(isPresented: $showPrivacy) { PrivacySettingsView() }
            .sheet(isPresented: $showLanguage) { LanguageSettingsView() }
            .sheet(isPresented: $showPaywall) { PaywallView(reason: .upgrade) }
            .alert("Reset all tutorials?", isPresented: $resetConfirmation) {
                Button("Reset", role: .destructive) {
                    TutorialManager.shared.resetAll()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Every tutorial will play again the next time you visit a feature.")
            }
        }
    }
}

struct PRow: View {
    let icon: String; let title: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.rwAccent).frame(width: 30)
                Text(title).font(RWF.body()).foregroundColor(.rwTextPrimary)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(.rwTextMuted)
            }
            .padding(.horizontal, SP.lg).padding(.vertical, 14)
        }
        .buttonStyle(SBS())
        Divider().padding(.horizontal, SP.lg).background(Color.rwBorder)
    }
}

// MARK: - Guide Sheet

struct GuideSheet: View {
    @Binding var open: Bool
    @State private var question = ""
    @State private var answer   = ""
    @State private var loading  = false
    @FocusState private var focused: Bool

    let prompts = ["I just got ghosted", "My matches aren't responding", "I have a date tonight",
                   "Bad date — what now?", "Profile not getting matches", "Just started seeing someone"]

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3).fill(Color.rwBorder)
                .frame(width: 40, height: 5).padding(.top, 12).padding(.bottom, 8)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask Cyrano").font(RWF.title(22)).foregroundColor(.rwTextPrimary)
                    Text("Tell me what's going on.").font(RWF.cap()).foregroundColor(.rwTextSecondary)
                }
                Spacer()
                Button { open = false } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.rwTextSecondary).frame(width: 32, height: 32)
                        .background(Color.rwCard).clipShape(Circle())
                }
            }
            .padding(.horizontal, SP.lg).padding(.bottom, SP.md)

            RWLine()

            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    if answer.isEmpty && !loading {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(prompts, id: \.self) { p in
                                    Button(p) { question = p; Task { await ask() } }
                                        .font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                                        .padding(.horizontal, 13).padding(.vertical, 8)
                                        .background(Color.rwCard).clipShape(Capsule())
                                        .overlay(Capsule().stroke(Color.rwBorder, lineWidth: 1))
                                        .buttonStyle(SBS())
                                }
                            }
                            .padding(.horizontal, SP.lg)
                        }
                    }

                    if loading {
                        HStack(spacing: 10) {
                            ProgressView().tint(.rwAccent)
                            Text("Thinking...").font(RWF.body()).foregroundColor(.rwTextSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, SP.lg)
                    }

                    if !answer.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                GlowDot()
                                Text("Cyrano").font(RWF.micro()).foregroundColor(.rwAccent).tracking(1.5)
                            }
                            Text(answer).font(RWF.body()).foregroundColor(.rwTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(SP.lg).background(Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
                        .padding(.horizontal, SP.lg)

                        Button { answer = ""; question = "" } label: {
                            Label("Ask something else", systemImage: "arrow.counterclockwise")
                                .font(RWF.cap()).foregroundColor(.rwTextMuted)
                        }
                    }

                    Spacer().frame(height: 80)
                }
                .padding(.top, SP.lg)
            }

            RWLine()
            HStack(spacing: 12) {
                TextField("", text: $question, prompt: Text("What's on your mind?").foregroundColor(.rwTextMuted))
                    .font(RWF.body()).foregroundColor(.rwTextPrimary).focused($focused)
                    .onSubmit { Task { await ask() } }
                Button { Task { await ask() } } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 28, design: .rounded))
                        .foregroundColor(question.isEmpty ? .rwTextMuted : .rwAccent)
                }
                .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty).buttonStyle(SBS())
            }
            .padding(.horizontal, SP.lg).padding(.vertical, 14).background(Color.rwSurface)
        }
        .background(Color.rwSurface)
        .clipShape(RoundedRectangle(cornerRadius: RR.xxl))
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focused = true } }
    }

    func ask() async {
        let q = question.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        loading = true; answer = ""
        let user = AuthService.shared.currentUser ?? RWUser()
        do { answer = try await Claude.shared.guide(question: q, user: user) }
        catch { answer = "Something went wrong. Please try again." }
        loading = false
    }
}

// MARK: - Language Settings View

struct LanguageSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var user = AuthService.shared.currentUser ?? RWUser()

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cyrano will respond in your chosen language. The app interface stays in English.")
                            .font(RWF.body()).foregroundColor(.rwTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(AppLanguage.allCases) { lang in
                            Button {
                                user.preferredLanguage = lang
                                AuthService.shared.save(user)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack(spacing: 10) {
                                    Text(lang.flag).font(.system(size: 22, design: .rounded))
                                    Text(lang.rawValue).font(RWF.med(13)).foregroundColor(.rwTextPrimary)
                                    Spacer()
                                    if user.preferredLanguage == lang {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.rwAccent).font(.system(size: 14, design: .rounded))
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
                        }
                    }
                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, SP.lg).padding(.top, 16)
            }
            .rwBG()
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.rwAccent)
                }
            }
        }
    }
}
