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

    var body: some View {
        Group {
            if SafetyManager.isJailbroken {
                JailbreakBlockView()
            } else if showSplash {
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
        .animation(.easeInOut(duration: 0.35), value: appState.hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.35), value: ageVerified)
        .animation(.easeInOut(duration: 0.35), value: isLocked)
        .animation(.easeInOut(duration: 0.5), value: showSplash)
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
                    .font(.system(size: 15, weight: .medium))
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
