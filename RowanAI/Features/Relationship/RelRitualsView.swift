import SwiftUI

// MARK: - Guided Rituals (Build 1 Step 6, Pillar 3)
// Daily + weekly rituals + meditations. Partner-sync (e.g., "revealed when
// both done") lands once partner pairing is live; until then the local-only
// version records the user's side and shows it back.

struct RelRitualsView: View {
    @State private var store = RelationshipStore.shared
    @State private var showMeditation: MeditationKind? = nil
    @State private var showRitual: RitualKind? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                hero
                section(title: "DAILY") {
                    RitualCard(kind: .morningIntention) { showRitual = .morningIntention }
                    RitualCard(kind: .eveningDebrief)   { showRitual = .eveningDebrief }
                    RitualCard(kind: .sixSecondKiss)    { showRitual = .sixSecondKiss }
                }
                section(title: "WEEKLY") {
                    RitualCard(kind: .stateOfUs)        { showRitual = .stateOfUs }
                    RitualCard(kind: .appreciation)     { showRitual = .appreciation }
                    RitualCard(kind: .growthChallenge)  { showRitual = .growthChallenge }
                }
                section(title: "MEDITATIONS") {
                    MeditationCard(kind: .lovingKindness)  { showMeditation = .lovingKindness }
                    MeditationCard(kind: .breathwork)      { showMeditation = .breathwork }
                    MeditationCard(kind: .gratitude)       { showMeditation = .gratitude }
                    MeditationCard(kind: .worryOffload)    { showMeditation = .worryOffload }
                }
                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg).padding(.top, 16)
        }
        .rwBG()
        .sheet(item: $showRitual) { kind in RitualSheet(kind: kind) }
        .sheet(item: $showMeditation) { kind in MeditationSheet(kind: kind) }
    }

    private var hero: some View {
        RWPageHeader("Rituals",
                     subtitle: "Small, repeatable acts that build connection on autopilot.",
                     topPadding: 0)
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RWSectionLabel(title)
            VStack(spacing: 8) { content() }
        }
    }
}

// MARK: - Ritual model

enum RitualKind: String, Identifiable {
    case morningIntention, eveningDebrief, sixSecondKiss
    case stateOfUs, appreciation, growthChallenge
    var id: String { rawValue }

    var title: String {
        switch self {
        case .morningIntention: return "Morning Intention"
        case .eveningDebrief:   return "Evening Debrief"
        case .sixSecondKiss:    return "6-Second Kiss"
        case .stateOfUs:        return "State of Us"
        case .appreciation:     return "Appreciation Practice"
        case .growthChallenge:  return "Growth Challenge"
        }
    }

    var sub: String {
        switch self {
        case .morningIntention: return "One appreciation, both submit privately, revealed together."
        case .eveningDebrief:   return "Three short questions about the day."
        case .sixSecondKiss:    return "A six-second kiss daily — Gottman-backed connection ritual."
        case .stateOfUs:        return "Six-dimension health check, weekly. Cyrano synthesises."
        case .appreciation:     return "Three specific things you valued about them this week."
        case .growthChallenge:  return "One research-backed challenge a week. Library of 52."
        }
    }

    var icon: String {
        switch self {
        case .morningIntention: return "sun.max.fill"
        case .eveningDebrief:   return "moon.stars.fill"
        case .sixSecondKiss:    return "heart.fill"
        case .stateOfUs:        return "chart.bar.doc.horizontal"
        case .appreciation:     return "sparkles"
        case .growthChallenge:  return "leaf.fill"
        }
    }

    var tint: Color {
        switch self {
        case .morningIntention: return Color(hex: "F59E0B")
        case .eveningDebrief:   return Color(hex: "5B8DEF")
        case .sixSecondKiss:    return .rwAccent
        case .stateOfUs:        return Color(hex: "00BFB3")
        case .appreciation:     return Color(hex: "9B59B6")
        case .growthChallenge:  return Color(hex: "00BFB3")
        }
    }
}

private struct RitualCard: View {
    let kind: RitualKind
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: kind.icon)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(kind.tint)
                    .frame(width: 44, height: 44)
                    .background(kind.tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.title).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                    Text(kind.sub).font(RWF.body(12)).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
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

// MARK: - Ritual sheet (functional starter; partner-sync in a later build)

struct RitualSheet: View {
    let kind: RitualKind
    @Environment(\.dismiss) private var dismiss
    @State private var entry: String = ""
    @State private var saved = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SP.md) {
                    headerCard
                    if kind == .sixSecondKiss {
                        kissReminderCard
                    } else {
                        entryField
                        if saved {
                            Text("Saved. Your partner's side appears here when partner-sync is live.")
                                .font(RWF.cap(12)).foregroundColor(.rwTextMuted)
                                .padding(.top, 4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        RWButton(saved ? "Saved" : "Save", icon: saved ? "checkmark" : "tray.and.arrow.down.fill") {
                            saved = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            // Bump RI Score consistency dimension when a ritual is logged.
                            RIScoreStore.shared.bumpConsistency(by: 2)
                        }
                        .disabled(saved || entry.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity((saved || entry.trimmingCharacters(in: .whitespaces).isEmpty) ? 0.6 : 1)
                    }
                }
                .padding(SP.lg)
            }
            .rwBG()
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.rwAccent)
                }
            }
        }
    }

    private var headerCard: some View {
        RWCard {
            VStack(alignment: .leading, spacing: 6) {
                Label("Why this matters", systemImage: "info.circle.fill")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                Text(kind.sub).font(RWF.body()).foregroundColor(.rwTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var entryField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(prompt).font(RWF.cap()).foregroundColor(.rwTextMuted)
            TextField("", text: $entry,
                      prompt: Text("Write here…").foregroundColor(.rwTextMuted),
                      axis: .vertical)
                .lineLimit(3...8)
                .font(RWF.body()).foregroundColor(.rwTextPrimary)
                .padding(SP.md).background(Color.rwCard)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        }
    }

    private var prompt: String {
        switch kind {
        case .morningIntention:
            return "One thing you appreciate about them today."
        case .eveningDebrief:
            return "Three short answers: what was good, what was hard, what do you need from them tomorrow?"
        case .stateOfUs:
            return "Trust · Communication · Intimacy · Fun · Stability · Growth — rate each 1-5 and add one note."
        case .appreciation:
            return "Three specific things they did this week that mattered to you."
        case .growthChallenge:
            return "Pick a challenge for the week (a Cyrano-curated library lands later) and write what you'll try."
        case .sixSecondKiss:
            return ""
        }
    }

    private var kissReminderCard: some View {
        RWCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Today's reminder", systemImage: "heart.fill")
                    .font(RWF.cap()).foregroundColor(.rwAccent)
                Text("A six-second kiss daily — research from Gottman shows it functions as a tiny stress-reset and recommitment ritual. Six seconds is long enough to break the autopilot peck.")
                    .font(RWF.body()).foregroundColor(.rwTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle("Remind me daily at 6pm",
                       isOn: Binding(
                        get: { UserDefaults.standard.bool(forKey: "rel.kissReminder") },
                        set: { newValue in
                            UserDefaults.standard.set(newValue, forKey: "rel.kissReminder")
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }))
                    .tint(.rwAccent)
            }
        }
    }
}

// MARK: - Meditations

enum MeditationKind: String, Identifiable {
    case lovingKindness, breathwork, gratitude, worryOffload
    var id: String { rawValue }

    var title: String {
        switch self {
        case .lovingKindness: return "Loving-Kindness"
        case .breathwork:     return "Breathwork for Conflict"
        case .gratitude:      return "Gratitude Visualization"
        case .worryOffload:   return "The Worry Offload"
        }
    }
    var minutes: Int {
        switch self {
        case .lovingKindness: return 5
        case .breathwork:     return 3
        case .gratitude:      return 7
        case .worryOffload:   return 4
        }
    }
    var icon: String {
        switch self {
        case .lovingKindness: return "heart.text.square.fill"
        case .breathwork:     return "wind"
        case .gratitude:      return "sparkles"
        case .worryOffload:   return "tray.and.arrow.up.fill"
        }
    }
    var script: String {
        switch self {
        case .lovingKindness:
            return "Settle in. Bring your partner's face to mind — not the version that frustrates you, the version you first loved. May they be safe. May they be at ease. May they feel loved by me. Repeat slowly. Notice what shifts."
        case .breathwork:
            return "If you've just had a hard moment together, breathe in for four, hold for two, out for six. Repeat ten times. The exhale is doing the work — that's how you tell your body it's safe."
        case .gratitude:
            return "Pick three specific things they did this week — not abstract qualities, real moments. Hold each one until you can feel it as fact, not concept. This is how appreciation becomes felt rather than performed."
        case .worryOffload:
            return "Speak or type the worry to Cyrano — privately, only you. Get it out of your head and into a place that can hold it. Then close it and return to your evening. Loop later if you need to."
        }
    }
}

private struct MeditationCard: View {
    let kind: MeditationKind
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: kind.icon)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.rwGold)
                    .frame(width: 44, height: 44)
                    .background(Color.rwGold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.title).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                    Text("\(kind.minutes) min").font(RWF.cap(11)).foregroundColor(.rwTextMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill").foregroundColor(.rwGold)
            }
            .padding(SP.md).background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        }
        .buttonStyle(SBS())
    }
}

struct MeditationSheet: View {
    let kind: MeditationKind
    @Environment(\.dismiss) private var dismiss
    @State private var playing = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.md) {
                    Image(systemName: kind.icon)
                        .font(.system(size: 48, design: .rounded))
                        .foregroundColor(.rwGold)
                        .padding(.top, 32)
                    Text(kind.title).font(RWF.title()).foregroundColor(.rwTextPrimary)
                    Text("\(kind.minutes) min").font(RWF.cap()).foregroundColor(.rwTextMuted)
                    RWCard {
                        Text(kind.script).font(RWF.body()).foregroundColor(.rwTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    RWButton(playing ? "Stop" : "Play (Apple voice)",
                             icon: playing ? "stop.fill" : "play.fill") {
                        if playing {
                            AppleTTSService.shared.stop()
                            playing = false
                        } else {
                            AppleTTSService.shared.speak(kind.script)
                            playing = true
                        }
                    }
                    if !StoreManager.shared.isPro {
                        Text("Pro unlocks the full ElevenLabs narration.")
                            .font(RWF.cap(11)).foregroundColor(.rwTextMuted)
                    }
                }
                .padding(SP.lg)
            }
            .rwBG()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.rwAccent)
                }
            }
            .onDisappear { AppleTTSService.shared.stop() }
        }
    }
}
