import SwiftUI

@main
struct RowanAIApp: App {
    @State private var appState = AppState()

    init() {
        // Kick off StoreKit product fetch + entitlement check before the
        // paywall is ever shown. Idempotent — safe to call again later.
        Task { @MainActor in
            StoreManager.shared.prepare()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) var appState
    @State private var safety = SafetyManager.shared
    @State private var ageVerified: Bool = UserDefaults.standard.bool(forKey: "ageVerified")
    @State private var isLocked: Bool = false
    @State private var showLaunch: Bool = true
    @State private var showSplash: Bool = true
    @State private var showPrivacyScreen: Bool = false
    @State private var ftue = FTUEManager.shared
    @State private var showJailbreakWarning: Bool = SafetyManager.isJailbroken
    // First-launch migration backstop — users who completed onboarding before
    // v1.0's name-step shipped will have an empty userDisplayName. The
    // fullScreenCover below catches them and asks for a name before the app
    // settles. New users won't see it because the onboarding name step writes
    // userDisplayName before hasCompletedOnboarding flips true.
    @AppStorage("userDisplayName") private var userDisplayName: String = ""
    // v1.1 About You migration. Two ways the dismiss flag gets set to true:
    //   1. The migration prompt itself — either "Let's go" or "Maybe later"
    //      sets it (one-shot cover).
    //   2. The onboarding step (case 15 in OnboardingFlowView) sets it on
    //      both Continue and Skip-for-now. Any user who completed the new
    //      onboarding flow has already had their chance to fill in About
    //      You, so the migration cover should never fire for them.
    // The 4-empty check below is a second line of defense: even if the
    // flag hasn't been set for some reason, a user with any About You
    // content won't see the prompt.
    @AppStorage("aboutYouMigrationDismissed") private var aboutYouMigrationDismissed: Bool = false
    @AppStorage("userHobbies")    private var userHobbies: String    = ""
    @AppStorage("userGreenFlags") private var userGreenFlags: String = ""
    @AppStorage("userRedFlags")   private var userRedFlags: String   = ""
    @AppStorage("userVibes")      private var userVibes: String      = ""

    @State private var showAboutYouSheet: Bool = false

    var body: some View {
        Group {
            if showSplash {
                SplashView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                showSplash = false
                            }
                        }
                    }
            } else if !ageVerified {
                AgeGate {
                    UserDefaults.standard.set(true, forKey: "ageVerified")
                    withAnimation { ageVerified = true }
                } onDecline: {
                    // Can't use the app — show message
                    UserDefaults.standard.set(false, forKey: "ageVerified")
                }
            } else if isLocked && safety.requiresBiometrics {
                LockScreen {
                    withAnimation { isLocked = false }
                }
            } else if !appState.hasCompletedOnboarding {
                OnboardingFlowView()
                    .onDisappear {
                        Task {
                            let _ = await NotificationManager.shared.requestPermission()
                            NotificationManager.shared.scheduleDailyStreakReminder()
                            NotificationManager.shared.scheduleWeeklyInsight()
                            // Build 1 Step 12 — Sunday 6pm Weekly Connection Report.
                            WeeklyReportService.shared.scheduleSundayReminder()
                        }
                        // First time the user reaches the app — kick off the
                        // 12-slide FTUE tour. Restart entry lives in Settings.
                        if !ftue.hasSeen { ftue.shouldShow = true }
                    }
            } else {
                // Build 1 Step 4 — replaces TabView with the radial arc nav.
                // MainTabView is preserved for now in case we need to roll back.
                ArcMainView()
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                        safety.updateActivity()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        safety.lockIfNeeded()
                        if !safety.isAuthenticated && safety.requiresBiometrics {
                            isLocked = true
                        }
                    }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: appState.hasCompletedOnboarding)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: ageVerified)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: isLocked)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: showSplash)
        // Jailbreak — soft warning instead of a hard block. Shown once per
        // session on jailbroken devices, dismissible so users can continue.
        .overlay(alignment: .top) {
            if showJailbreakWarning {
                JailbreakWarningBanner {
                    withAnimation(.easeInOut(duration: 0.2)) { showJailbreakWarning = false }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // Privacy overlay — hides sensitive content in the app switcher and prevents screenshots
        // from capturing relationship data, contact archive, or coaching conversations.
        .overlay {
            if showPrivacyScreen {
                ZStack {
                    Color.rwBackground.ignoresSafeArea()
                    VStack(spacing: 16) {
                        RowanLogo(size: 72).opacity(0.35)
                        Text("rowan")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "1B2B4B"))
                            .opacity(0.35)
                    }
                }
                .transition(.opacity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) { showPrivacyScreen = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { showPrivacyScreen = false }
        }
        // 12-slide first-time tour — shows after onboarding for new users,
        // and again whenever Settings → Restart Tour sets shouldShow = true.
        .fullScreenCover(isPresented: Binding(
            get: { ftue.shouldShow && appState.hasCompletedOnboarding },
            set: { ftue.shouldShow = $0 }
        )) {
            FTUEView { ftue.shouldShow = false }
        }
        // v1.0 first-launch backstop — users who completed onboarding before
        // the new in-flow name step shipped have an empty userDisplayName.
        // The cover auto-dismisses when the callback writes to
        // userDisplayName (the Binding.get flips false). New users never
        // see it because the onboarding step writes the value before
        // hasCompletedOnboarding flips true.
        .fullScreenCover(isPresented: Binding(
            get: { appState.hasCompletedOnboarding && userDisplayName.isEmpty },
            set: { _ in }
        )) {
            NameEntryView(
                eyebrow: "WELCOME BACK",
                headline: "What should we call you?",
                subtext: "We've made some upgrades. A first name or nickname is perfect.",
                initialValue: "",
                onContinue: { name in
                    userDisplayName = name
                },
                onSkip: {
                    userDisplayName = "you"
                }
            )
        }
        // v1.1 About You migration — shown once to users who completed
        // onboarding before this feature shipped. Gated on:
        //   • onboarding complete
        //   • the one-shot dismiss flag is still false
        //   • all four About You fields are empty (otherwise they've
        //     already engaged with the feature — no need to prompt).
        //   • name migration is settled (userDisplayName non-empty) so
        //     the two covers don't stack on first launch.
        .fullScreenCover(isPresented: Binding(
            get: {
                appState.hasCompletedOnboarding
                    && !aboutYouMigrationDismissed
                    && !userDisplayName.isEmpty
                    && userHobbies.isEmpty
                    && userGreenFlags.isEmpty
                    && userRedFlags.isEmpty
                    && userVibes.isEmpty
            },
            set: { _ in }
        )) {
            AboutYouMigrationPrompt(
                onAccept: {
                    aboutYouMigrationDismissed = true
                    // Open the edit sheet on the next runloop tick so the
                    // cover has time to dismiss cleanly before the sheet
                    // presents.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showAboutYouSheet = true
                    }
                },
                onDecline: {
                    aboutYouMigrationDismissed = true
                }
            )
        }
        .sheet(isPresented: $showAboutYouSheet) {
            AboutYouEditSheet()
        }
    }
}

// MARK: - Splash Screen

struct SplashView: View {
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var wordmarkOpacity: Double = 0
    @State private var wordmarkOffset: CGFloat = 10

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 16) {
                RowanLogo(size: 80)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                Text("rowan")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "1B2B4B"))
                    .opacity(wordmarkOpacity)
                    .offset(y: wordmarkOffset)

                Text("Built for love. Not likes.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "9BA8BF"))
                    .opacity(wordmarkOpacity)
                    .offset(y: wordmarkOffset)
            }
        }
        .onAppear {
            // Logo bounces in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.1)) {
                logoScale   = 1.0
                logoOpacity = 1.0
            }
            // Wordmark slides up and fades in
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                wordmarkOpacity = 1.0
                wordmarkOffset  = 0
            }
        }
    }
}
