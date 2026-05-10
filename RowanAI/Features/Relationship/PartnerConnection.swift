import SwiftUI
import CryptoKit

// MARK: - Partner Connection Store

@Observable
class PartnerStore {
    static let shared = PartnerStore()

    var myCode: String = ""
    var partnerCode: String = ""
    var isConnected: Bool = false
    var partnerName: String = ""
    var partnerHealthChecks: [SharedHealthCheck] = []
    var pendingNudge: RelNudge? = nil

    private let key = "partner_connection_v1"
    private let healthKey = "shared_health_v1"

    // Stored as .completeFileProtection files — encrypted when device is locked
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("partner_connection_v1.json")
    }

    private var healthFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("partner_health_v1.json")
    }

    init() { load() }

    func load() {
        // Partner data: migrate from UserDefaults to encrypted file on first upgrade
        if !FileManager.default.fileExists(atPath: fileURL.path),
           let data = UserDefaults.standard.data(forKey: key),
           let stored = try? JSONDecoder().decode(PartnerData.self, from: data) {
            myCode = stored.myCode
            partnerCode = stored.partnerCode
            isConnected = stored.isConnected
            partnerName = stored.partnerName
            save()
            UserDefaults.standard.removeObject(forKey: key)
        } else if let data = try? Data(contentsOf: fileURL),
                  let stored = try? JSONDecoder().decode(PartnerData.self, from: data) {
            myCode = stored.myCode
            partnerCode = stored.partnerCode
            isConnected = stored.isConnected
            partnerName = stored.partnerName
        } else {
            myCode = generateCode()
            save()
        }

        // Health checks: migrate from UserDefaults to encrypted file on first upgrade
        if !FileManager.default.fileExists(atPath: healthFileURL.path),
           let data = UserDefaults.standard.data(forKey: healthKey),
           let stored = try? JSONDecoder().decode([SharedHealthCheck].self, from: data) {
            partnerHealthChecks = stored
            saveHealth()
            UserDefaults.standard.removeObject(forKey: healthKey)
        } else if let data = try? Data(contentsOf: healthFileURL),
                  let stored = try? JSONDecoder().decode([SharedHealthCheck].self, from: data) {
            partnerHealthChecks = stored
        }
    }

    func save() {
        guard let encoded = try? JSONEncoder().encode(
            PartnerData(myCode: myCode, partnerCode: partnerCode,
                        isConnected: isConnected, partnerName: partnerName)
        ) else { return }
        try? encoded.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func saveHealth() {
        guard let encoded = try? JSONEncoder().encode(partnerHealthChecks) else { return }
        try? encoded.write(to: healthFileURL, options: [.atomic, .completeFileProtection])
    }

    func connect(code: String, name: String) {
        partnerCode = code
        partnerName = name
        isConnected = true
        save()
    }

    func disconnect() {
        partnerCode = ""; partnerName = ""; isConnected = false
        save()
    }

    func generateCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    // MARK: - Nudge Detection

    func checkForNudge() {
        let checks = RelationshipStore.shared.relationship?.healthChecks ?? []
        guard checks.count >= 3 else { return }
        let recent = checks.sorted { $0.date > $1.date }.prefix(3)
        let avgScores = recent.map { $0.averageScore }
        let allLow = avgScores.allSatisfy { $0 < 3.0 }
        if allLow {
            pendingNudge = RelNudge(
                type: .lowConnection,
                weeksLow: 3,
                lowestDimension: lowestDimension(recent.first))
        }
    }

    func lowestDimension(_ check: HealthCheck?) -> String {
        guard let check = check else { return "Quality Time" }
        return check.scores.min(by: { $0.value < $1.value })?.key ?? "Quality Time"
    }
}

struct PartnerData: Codable {
    var myCode: String; var partnerCode: String
    var isConnected: Bool; var partnerName: String
}

struct SharedHealthCheck: Codable, Identifiable {
    var id = UUID().uuidString
    var date = Date()
    var partnerAvgScore: Double
    var myAvgScore: Double
    var partnerName: String
}

struct RelNudge: Identifiable {
    let id = UUID()
    var type: NudgeType
    var weeksLow: Int
    var lowestDimension: String

    enum NudgeType { case lowConnection, dateSuggestion }
}

// MARK: - Partner Connection View

struct PartnerConnectionView: View {
    @State private var store = PartnerStore.shared
    @State private var relStore = RelationshipStore.shared
    @State private var mode: ConnMode = .main
    @State private var enteredCode = ""
    @State private var enteredName = ""
    @State private var copied = false
    @State private var showDisconnect = false
    @Environment(\.dismiss) var dismiss

    enum ConnMode { case main, connect }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    if store.isConnected {
                        connectedView
                    } else if mode == .connect {
                        connectView
                    } else {
                        disconnectedView
                    }
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, SP.lg).padding(.top, 16)
            }
            .rwBG()
            .navigationTitle("Partner Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.rwAccent)
                }
            }
            .confirmationDialog("Disconnect from \(store.partnerName)?", isPresented: $showDisconnect) {
                Button("Disconnect", role: .destructive) { store.disconnect() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    var disconnectedView: some View {
        VStack(spacing: SP.xl) {
            VStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 52, design: .rounded))
                    .foregroundStyle(LinearGradient.accent)
                Text("Connect with your partner").font(RWF.title(22)).foregroundColor(.rwTextPrimary)
                    .multilineTextAlignment(.center)
                Text("When you're both connected, Rowan tracks your relationship health from both sides and nudges you when things need attention.")
                    .font(RWF.body()).foregroundColor(.rwTextSecondary).multilineTextAlignment(.center)
            }

            // My code
            VStack(spacing: 10) {
                Text("Your connection code").font(RWF.cap()).foregroundColor(.rwTextMuted)
                HStack(spacing: 8) {
                    Text(store.myCode)
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundColor(.rwTextPrimary)
                        .tracking(8)
                    Button {
                        UIPasteboard.general.string = store.myCode
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    } label: {
                        Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 20, design: .rounded))
                            .foregroundColor(copied ? .rwSuccess : .rwTextMuted)
                    }
                    .buttonStyle(SBS())
                }
                .padding(SP.lg).background(Color.rwSurface)
                .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))

                Text("Share this with your partner. They enter it in their app.")
                    .font(RWF.cap(12)).foregroundColor(.rwTextMuted).multilineTextAlignment(.center)
            }

            RWButton("Enter My Partner's Code", icon: "link") {
                withAnimation { mode = .connect }
            }

            Text("Both of you need Rowan installed. This is local — no account required.")
                .font(.system(size: 11, design: .rounded)).foregroundColor(.rwTextMuted).multilineTextAlignment(.center)
        }
    }

    var connectView: some View {
        VStack(spacing: SP.xl) {
            VStack(spacing: 8) {
                Text("Enter their code").font(RWF.title(22)).foregroundColor(.rwTextPrimary)
                Text("Ask your partner to open Rowan and share their 6-digit code with you.")
                    .font(RWF.body()).foregroundColor(.rwTextSecondary).multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                TextField("", text: $enteredCode, prompt: Text("XXXXXX").foregroundColor(.rwTextMuted))
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundColor(.rwTextPrimary).tracking(8)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .padding(SP.lg).background(Color.rwSurface)
                    .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                    .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))

                SF(label: "Their name", icon: "person.fill", ph: "Your partner's name", text: $enteredName)
            }

            RWButton("Connect", icon: "link") {
                guard enteredCode.count == 6 && !enteredName.isEmpty else { return }
                store.connect(code: enteredCode.uppercased(), name: enteredName)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation { mode = .main }
            }
            .disabled(enteredCode.count < 6 || enteredName.isEmpty)
            .opacity(enteredCode.count < 6 || enteredName.isEmpty ? 0.5 : 1)

            Button("Back") { withAnimation { mode = .main } }
                .font(RWF.cap()).foregroundColor(.rwTextMuted)
        }
    }

    var connectedView: some View {
        VStack(spacing: SP.lg) {
            VStack(spacing: 10) {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("You").font(RWF.cap()).foregroundColor(.rwTextMuted)
                        Circle().fill(Color.rwAccent.opacity(0.15)).frame(width: 56, height: 56)
                            .overlay(Text(String(AuthService.shared.currentUser?.name.prefix(1) ?? "Y").uppercased())
                                .font(RWF.head(22)).foregroundColor(.rwAccent))
                    }
                    VStack(spacing: 6) {
                        Image(systemName: "heart.fill").font(.system(size: 20, design: .rounded)).foregroundColor(.rwAccent)
                        RoundedRectangle(cornerRadius: 2).fill(Color.rwAccent.opacity(0.3))
                            .frame(width: 40, height: 2)
                    }
                    VStack(spacing: 4) {
                        Text(store.partnerName).font(RWF.cap()).foregroundColor(.rwTextMuted)
                        Circle().fill(Color(hex: "5B8DEF").opacity(0.15)).frame(width: 56, height: 56)
                            .overlay(Text(String(store.partnerName.prefix(1)).uppercased())
                                .font(RWF.head(22)).foregroundColor(Color(hex: "5B8DEF")))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(SP.lg).background(Color.rwSurface)
                .clipShape(RoundedRectangle(cornerRadius: RR.xl))

                HStack(spacing: 6) {
                    Circle().fill(Color.rwSuccess).frame(width: 8, height: 8)
                    Text("Connected with \(store.partnerName)").font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                }
            }

            // My code for them
            VStack(alignment: .leading, spacing: 8) {
                Text("Your code").font(RWF.cap()).foregroundColor(.rwTextMuted)
                HStack {
                    Text(store.myCode)
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(.rwTextPrimary).tracking(6)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = store.myCode
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "doc.on.doc").foregroundColor(.rwTextMuted)
                    }
                    .buttonStyle(SBS())
                }
                .padding(SP.md).background(Color.rwSurface)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            }

            // How it works
            RWCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What happens now").font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                    ConnInfoRow(icon: "heart.text.square.fill", color: Color(hex: "E8356D"),
                        text: "Weekly health checks are tracked from both sides")
                    ConnInfoRow(icon: "bell.badge.fill", color: Color(hex: "F59E0B"),
                        text: "If 3 weeks of low scores detected, Cyrano steps in with a suggestion")
                    ConnInfoRow(icon: "bubble.left.and.bubble.right.fill", color: Color(hex: "5B8DEF"),
                        text: "Hard conversation templates can be shared with your partner")
                    ConnInfoRow(icon: "lock.fill", color: Color(hex: "9BA8BF"),
                        text: "Your individual notes and journal stay private")
                }
            }

            Button("Disconnect", role: .destructive) { showDisconnect = true }
                .font(RWF.cap()).foregroundColor(.rwDanger)
        }
    }
}

struct ConnInfoRow: View {
    let icon: String; let color: Color; let text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(color).frame(width: 28)
            Text(text).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Proactive Nudge Banner

struct RelNudgeBanner: View {
    @State private var store = PartnerStore.shared
    @State private var relStore = RelationshipStore.shared
    @State private var suggestion = ""
    @State private var isLoading = false
    @State private var dismissed = false

    var body: some View {
        if let nudge = store.pendingNudge, !dismissed {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "heart.slash.fill")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color(hex: "E8356D"))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cyrano noticed something")
                            .font(RWF.head(14)).foregroundColor(.rwTextPrimary)
                        Text("\(nudge.weeksLow) weeks of low \(nudge.lowestDimension.lowercased()) scores.")
                            .font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                    }
                    Spacer()
                    Button { withAnimation { dismissed = true } } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.rwTextMuted).frame(width: 24, height: 24)
                            .background(Color.rwSurface).clipShape(Circle())
                    }
                    .buttonStyle(SBS())
                }

                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView().tint(.rwAccent).scaleEffect(0.8)
                        Text("Cyrano is thinking...").font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                    }
                } else if !suggestion.isEmpty {
                    Text(suggestion).font(RWF.body(13)).foregroundColor(.rwTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(SP.md).background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color(hex: "E8356D").opacity(0.2), lineWidth: 1))
            .shadow(color: Color(hex: "E8356D").opacity(0.1), radius: 8, x: 0, y: 2)
            .onAppear { Task { await loadSuggestion(nudge) } }
        }
    }

    func loadSuggestion(_ nudge: RelNudge) async {
        isLoading = true
        let rel = relStore.relationship
        let partner = rel?.partnerName ?? "your partner"
        let months = rel?.monthsTogether ?? 0
        let system = """
        You are Cyrano, a relationship coach. A couple has had 3 consecutive weeks of low relationship health scores, particularly in \(nudge.lowestDimension).
        They have been together \(months) months. Partner's name: \(partner).
        Suggest ONE specific, actionable thing they can do this week — either a date night idea or a conversation starter.
        Be warm, specific, and practical. 2-3 sentences max.
        """
        do {
            suggestion = try await Claude.shared.send(system: system, user: "Suggest something specific to help reconnect.", max: 200)
        } catch {
            suggestion = "Consider planning something simple together this week — even a walk or a meal at home with phones away can reset the connection."
        }
        isLoading = false
    }
}
