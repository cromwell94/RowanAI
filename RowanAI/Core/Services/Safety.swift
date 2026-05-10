import SwiftUI
import LocalAuthentication

// MARK: - Safety Manager

@Observable
class SafetyManager {
    static let shared = SafetyManager()

    var isAuthenticated: Bool = false
    var requiresBiometrics: Bool {
        get { UserDefaults.standard.bool(forKey: "biometricsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "biometricsEnabled") }
    }
    var lastActiveTime: Date = Date()
    var autoLockMinutes: Int {
        get { UserDefaults.standard.integer(forKey: "autoLockMinutes") == 0 ? 5 : UserDefaults.standard.integer(forKey: "autoLockMinutes") }
        set { UserDefaults.standard.set(newValue, forKey: "autoLockMinutes") }
    }

    // MARK: - Biometric Auth

    func authenticate() async -> Bool {
        guard requiresBiometrics else { isAuthenticated = true; return true }
        let context = LAContext()
        var error: NSError?
        // Use deviceOwnerAuthentication so passcode is offered as fallback when biometrics
        // are unavailable or not enrolled — do NOT silently grant access in that case.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isAuthenticated = false; return false
        }
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Rowan")
            isAuthenticated = success
            return success
        } catch {
            isAuthenticated = false
            return false
        }
    }

    func lockIfNeeded() {
        guard requiresBiometrics else { return }
        let elapsed = Date().timeIntervalSince(lastActiveTime)
        if elapsed > Double(autoLockMinutes * 60) {
            isAuthenticated = false
        }
    }

    func updateActivity() {
        lastActiveTime = Date()
    }

    // MARK: - Crisis Detection

    static let crisisKeywords = [
        "kill myself", "want to die", "end my life", "suicide", "suicidal",
        "self harm", "hurt myself", "cutting myself", "don't want to be here",
        "can't go on", "no reason to live", "abuse", "he hits me", "she hits me",
        "being abused", "scared of them", "afraid of them", "threatening me",
        "stalking me", "won't leave me alone"
    ]

    static func containsCrisisContent(_ text: String) -> Bool {
        let lower = text.lowercased()
        return crisisKeywords.contains { lower.contains($0) }
    }

    // MARK: - Content Safety Check

    static let harmfulPatterns = [
        "how to stalk", "track their location without", "spy on",
        "get back at", "make them jealous enough to", "manipulate them into",
        "force them to", "blackmail"
    ]

    static func containsHarmfulIntent(_ text: String) -> Bool {
        let lower = text.lowercased()
        return harmfulPatterns.contains { lower.contains($0) }
    }

    // MARK: - Data Management

    func clearAllData() {
        // Clear UserDefaults
        let domain = Bundle.main.bundleIdentifier ?? "com.rakita.rowanai"
        UserDefaults.standard.removePersistentDomain(forName: domain)
        // Delete Keychain secrets (set-to-empty leaves the item; delete removes it)
        Keychain.delete("rw_user_profile")
        // Delete encrypted data files
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: docsDir.appendingPathComponent("archive_v1.json"))
        try? FileManager.default.removeItem(at: docsDir.appendingPathComponent("debriefs_v1.json"))
        try? FileManager.default.removeItem(at: docsDir.appendingPathComponent("relationship_v1.json"))
        try? FileManager.default.removeItem(at: docsDir.appendingPathComponent("partner_connection_v1.json"))
        try? FileManager.default.removeItem(at: docsDir.appendingPathComponent("partner_health_v1.json"))
        // Reset in-memory stores so the UI reflects the cleared state immediately
        ArchiveStore.shared.people = []
        DebriefStore.shared.debriefs = []
        PartnerStore.shared.myCode = ""
        PartnerStore.shared.partnerCode = ""
        PartnerStore.shared.partnerName = ""
        PartnerStore.shared.isConnected = false
        PartnerStore.shared.partnerHealthChecks = []
    }

    func exportData() -> String {
        var export = "Rowan Data Export\n"
        export += "Generated: \(Date().formatted())\n\n"

        if let user = AuthService.shared.currentUser {
            export += "Profile:\n"
            export += "Name: \(user.name)\n"
            export += "Goal: \(user.datingGoal.rawValue)\n"
            export += "Love Languages: \(user.loveLanguages.map { $0.rawValue }.joined(separator: ", "))\n\n"
        }

        let people = ArchiveStore.shared.people
        if !people.isEmpty {
            export += "Archive (\(people.count) people):\n"
            for p in people {
                export += "- \(p.name) (\(p.status.rawValue))\n"
            }
        }

        return export
    }

    // MARK: - Jailbreak Detection

    static var isJailbroken: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        // 1. Known jailbreak artefact paths
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Applications/FakeCarrier.app",
            "/Applications/Icy.app",
            "/Applications/IntelliScreen.app",
            "/Applications/WinterBoard.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
            "/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/private/var/stash",
            "/private/var/tmp/cydia.log",
            "/bin/bash",
            "/bin/sh",
            "/usr/sbin/sshd",
            "/usr/libexec/sftp-server",
            "/etc/apt",
            "/usr/bin/sshd"
        ]
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) { return true }
        }
        // 2. Sandbox escape test — stock devices cannot write outside their container
        let testPath = "/private/jailbreak_probe_\(ProcessInfo.processInfo.processIdentifier)"
        if (try? "x".write(toFile: testPath, atomically: true, encoding: .utf8)) != nil {
            try? FileManager.default.removeItem(atPath: testPath)
            return true
        }
        // 3. Dylib injection via environment variable (common in jailbroken Substrate tweaks)
        if let injected = ProcessInfo.processInfo.environment["DYLD_INSERT_LIBRARIES"],
           !injected.isEmpty { return true }
        return false
        #endif
    }
}

// MARK: - Crisis Banner

struct CrisisBanner: View {
    @Binding var show: Bool

    var body: some View {
        if show {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text("We noticed something important")
                        .font(RWF.head(15)).foregroundColor(.white)
                    Spacer()
                    Button { withAnimation { show = false } } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Text("If you or someone you know is struggling, please reach out. You don't have to figure this out alone.")
                    .font(RWF.body(14)).foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    if let call988 = URL(string: "tel:988") {
                        Link(destination: call988) {
                            HStack(spacing: 6) {
                                Image(systemName: "phone.fill").font(.system(size: 12, design: .rounded))
                                Text("Call 988").font(RWF.med(13))
                            }
                            .foregroundColor(Color(hex: "E8356D"))
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(.white).clipShape(Capsule())
                        }
                    }

                    if let textLine = URL(string: "sms:741741") {
                        Link(destination: textLine) {
                            HStack(spacing: 6) {
                                Image(systemName: "message.fill").font(.system(size: 12, design: .rounded))
                                Text("Text HOME to 741741").font(RWF.med(13))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(.white.opacity(0.2)).clipShape(Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
            }
            .padding(SP.lg)
            .background(
                LinearGradient(
                    colors: [Color(hex: "E8356D"), Color(hex: "5B8DEF")],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .shadow(color: Color(hex: "E8356D").opacity(0.3), radius: 16, x: 0, y: 6)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Lock Screen

struct LockScreen: View {
    @State private var failed = false
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            Color.rwBackground.ignoresSafeArea()
            VStack(spacing: SP.xl) {
                Spacer()
                RowanLogo(size: 64)
                Text("rowan").font(RWF.display(36)).foregroundColor(.rwTextPrimary)
                Spacer()
                VStack(spacing: 14) {
                    if failed {
                        Text("Authentication failed. Try again.")
                            .font(RWF.cap()).foregroundColor(.rwAccent)
                            .transition(.opacity)
                    }
                    RWButton("Unlock with Face ID", icon: "faceid") {
                        Task {
                            let success = await SafetyManager.shared.authenticate()
                            if success { onUnlock() }
                            else { withAnimation { failed = true } }
                        }
                    }
                    .padding(.horizontal, SP.xl)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            Task {
                let success = await SafetyManager.shared.authenticate()
                if success { onUnlock() }
            }
        }
    }
}

// MARK: - Age Gate

struct AgeGate: View {
    let onConfirm: () -> Void
    let onDecline: () -> Void

    var body: some View {
        ZStack {
            Color.rwBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: SP.lg) {
                    RowanLogo(size: 56)
                    Text("Age Verification").font(RWF.title()).foregroundColor(.rwTextPrimary)
                    Text("Rowan is designed for adults aged 18 and over. Please confirm your age to continue.")
                        .font(RWF.body()).foregroundColor(.rwTextSecondary)
                        .multilineTextAlignment(.center).padding(.horizontal, SP.xl)
                }
                Spacer()
                VStack(spacing: 12) {
                    RWButton("I am 18 or older — Continue", icon: "checkmark") { onConfirm() }
                    Button("I am under 18") { onDecline() }
                        .font(RWF.cap()).foregroundColor(.rwTextMuted)
                }
                .padding(.horizontal, SP.xl).padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Privacy Settings View

struct PrivacySettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var safety = SafetyManager.shared
    @State private var showClearConfirm = false
    @State private var showExport = false
    @State private var exportText = ""

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {

                    // Security
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Security").font(RWF.head()).foregroundColor(.rwTextPrimary)
                            .padding(.horizontal, SP.lg)

                        RWCard {
                            VStack(spacing: 0) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Face ID / Touch ID").font(RWF.med()).foregroundColor(.rwTextPrimary)
                                        Text("Require biometrics to open Rowan")
                                            .font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { safety.requiresBiometrics },
                                        set: { safety.requiresBiometrics = $0 }
                                    )).tint(.rwAccent).labelsHidden()
                                }
                                .padding(.bottom, 14)

                                RWLine()

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Auto-lock after").font(RWF.med()).foregroundColor(.rwTextPrimary)
                                        .padding(.top, 14)
                                    HStack(spacing: 8) {
                                        ForEach([1, 5, 15, 30], id: \.self) { mins in
                                            Button("\(mins)m") {
                                                safety.autoLockMinutes = mins
                                            }
                                            .font(RWF.cap(12))
                                            .foregroundColor(safety.autoLockMinutes == mins ? .white : .rwTextSecondary)
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(safety.autoLockMinutes == mins ? Color(hex: "0D0D0D") : Color.rwSurface)
                                            .clipShape(Capsule())
                                            .buttonStyle(SBS())
                                        }
                                    }
                                }
                                .opacity(safety.requiresBiometrics ? 1 : 0.4)
                                .disabled(!safety.requiresBiometrics)
                            }
                        }
                        .padding(.horizontal, SP.lg)
                    }

                    // Data
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Data").font(RWF.head()).foregroundColor(.rwTextPrimary)
                            .padding(.horizontal, SP.lg)

                        RWCard {
                            VStack(spacing: 14) {
                                DataRow(icon: "iphone", title: "Storage", detail: "On-device only")
                                RWLine()
                                DataRow(icon: "nosign", title: "Ads", detail: "None — ever")
                                RWLine()
                                DataRow(icon: "person.slash", title: "Third parties", detail: "None")
                                RWLine()
                                DataRow(icon: "network", title: "Data sent externally", detail: "Your messages to AI only")
                            }
                        }
                        .padding(.horizontal, SP.lg)

                        // Export
                        Button {
                            exportText = SafetyManager.shared.exportData()
                            showExport = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up").font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.rwTextPrimary).frame(width: 32)
                                Text("Export My Data").font(RWF.body()).foregroundColor(.rwTextPrimary)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
                            }
                            .padding(SP.md).background(Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
                            .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
                        }
                        .buttonStyle(SBS())
                        .padding(.horizontal, SP.lg)

                        // Delete
                        Button {
                            showClearConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill").font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(hex: "E8356D")).frame(width: 32)
                                Text("Delete All My Data").font(RWF.body()).foregroundColor(Color(hex: "E8356D"))
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
                            }
                            .padding(SP.md).background(Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color(hex: "E8356D").opacity(0.2), lineWidth: 1))
                            .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
                        }
                        .buttonStyle(SBS())
                        .padding(.horizontal, SP.lg)
                    }

                    // Crisis resources
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Support Resources").font(RWF.head()).foregroundColor(.rwTextPrimary)
                            .padding(.horizontal, SP.lg)

                        RWCard {
                            VStack(spacing: 12) {
                                CrisisLink(icon: "phone.fill", title: "988 Suicide & Crisis Lifeline",
                                    subtitle: "Call or text 988", url: "tel:988", color: Color(hex: "E8356D"))
                                RWLine()
                                CrisisLink(icon: "message.fill", title: "Crisis Text Line",
                                    subtitle: "Text HOME to 741741", url: "sms:741741", color: Color(hex: "5B8DEF"))
                                RWLine()
                                CrisisLink(icon: "person.2.fill", title: "National DV Hotline",
                                    subtitle: "1-800-799-7233", url: "tel:18007997233", color: Color(hex: "00BFB3"))
                            }
                        }
                        .padding(.horizontal, SP.lg)
                    }

                    Text("Rowan stores your data on your device. When you use AI features, your messages are sent to Anthropic's servers to generate responses. No data is sold or shared with advertisers.")
                        .font(.system(size: 11, design: .rounded)).foregroundColor(.rwTextMuted)
                        .multilineTextAlignment(.center).padding(.horizontal, SP.xl)

                    Spacer().frame(height: 60)
                }
                .padding(.top, 20)
            }
            .rwBG()
            .navigationTitle("Privacy & Security")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.rwAccent)
                }
            }
            .confirmationDialog("Delete all data?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) {
                    SafetyManager.shared.clearAllData()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your profile, archive, journal entries, and all settings. This cannot be undone.")
            }
            .sheet(isPresented: $showExport) {
                ShareSheet(text: exportText)
            }
        }
    }
}

struct DataRow: View {
    let icon: String; let title: String; let detail: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.rwTextSecondary).frame(width: 24)
            Text(title).font(RWF.body()).foregroundColor(.rwTextPrimary)
            Spacer()
            Text(detail).font(RWF.cap()).foregroundColor(.rwTextSecondary)
        }
    }
}

struct CrisisLink: View {
    let icon: String; let title: String; let subtitle: String; let url: String; let color: Color
    var body: some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                HStack(spacing: 12) {
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(color).frame(width: 36, height: 36)
                        .background(color.opacity(0.1)).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(RWF.med(14)).foregroundColor(.rwTextPrimary)
                        Text(subtitle).font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 12, design: .rounded)).foregroundColor(.rwTextMuted)
                }
            }
            .buttonStyle(SBS())
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Jailbreak Block Screen

struct JailbreakBlockView: View {
    var body: some View {
        ZStack {
            Color.rwBackground.ignoresSafeArea()
            VStack(spacing: SP.xl) {
                Spacer()
                Image(systemName: "lock.trianglebadge.exclamationmark.fill")
                    .font(.system(size: 64, design: .rounded))
                    .foregroundColor(.rwDanger)
                VStack(spacing: 12) {
                    Text("Security Check Failed")
                        .font(RWF.title()).foregroundColor(.rwTextPrimary)
                        .multilineTextAlignment(.center)
                    Text("Rowan cannot run on this device. Your private relationship data requires a secure, unmodified iOS environment.")
                        .font(RWF.body()).foregroundColor(.rwTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SP.xl)
                }
                Spacer()
            }
        }
    }
}
