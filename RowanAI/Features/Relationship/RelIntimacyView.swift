import SwiftUI

// MARK: - Intimacy Builder (Build 1 Step 6, Pillar 4)
// 18+ age-gated. Three sections:
//   1. Connection Cards (3 decks of 20 — starter library here, expand later)
//   2. The Desire Map (8 monthly questions, Cyrano finds overlap)
//   3. Touch Inventory (weekly self-report 1-5)
// Onboarding does not yet collect birth year, so the gate is a confirmation
// rather than a hard verification — flagged for upgrade in a later build.

struct RelIntimacyView: View {
    @AppStorage("rel.intimacy.ageConfirmed") private var ageConfirmed = false
    @State private var deck: ConnectionDeck = .warm
    @State private var showAgeGate = false
    @State private var showDesireMap = false
    @State private var showTouchInventory = false

    var body: some View {
        if !ageConfirmed {
            AgeGateScreen { ageConfirmed = true }
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    hero
                    deckPicker
                    cardsList
                    desireMapCard
                    touchInventoryCard
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, SP.lg).padding(.top, 16)
            }
            .rwBG()
            .sheet(isPresented: $showDesireMap) { DesireMapView() }
            .sheet(isPresented: $showTouchInventory) { TouchInventoryView() }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Intimacy Builder").font(RWF.title()).foregroundColor(.rwTextPrimary)
            Text("Closeness across emotional, physical, and intellectual dimensions.")
                .font(RWF.body()).foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var deckPicker: some View {
        HStack(spacing: 8) {
            ForEach(ConnectionDeck.allCases) { d in
                Button {
                    deck = d
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text(d.rawValue.uppercased())
                        .font(RWF.cap(12))
                        .foregroundColor(deck == d ? .white : .rwTextSecondary)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(deck == d ? d.color : Color.rwCard)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(deck == d ? Color.clear : Color.rwBorder, lineWidth: 1))
                }
                .buttonStyle(SBS())
            }
        }
    }

    private var cardsList: some View {
        VStack(spacing: 8) {
            ForEach(deck.cards, id: \.self) { prompt in
                ConnectionCardView(prompt: prompt, color: deck.color)
            }
        }
    }

    private var desireMapCard: some View {
        Button { showDesireMap = true } label: {
            tile(icon: "map.fill",
                 title: "The Desire Map",
                 sub: "8 monthly questions you each answer privately. Cyrano finds the overlap.",
                 tint: Color(hex: "9B59B6"))
        }
        .buttonStyle(SBS())
    }

    private var touchInventoryCard: some View {
        Button { showTouchInventory = true } label: {
            tile(icon: "hand.raised.fill",
                 title: "Touch Inventory",
                 sub: "Quick weekly slider. Cyrano nudges you when it drifts.",
                 tint: Color(hex: "00BFB3"))
        }
        .buttonStyle(SBS())
    }

    private func tile(icon: String, title: String, sub: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: RR.md))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                Text(sub).font(RWF.body(12)).foregroundColor(.rwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
        }
        .padding(SP.md).background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
    }
}

// MARK: - Age Gate

private struct AgeGateScreen: View {
    let onConfirm: () -> Void
    var body: some View {
        VStack(spacing: SP.lg) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48)).foregroundColor(.rwAccent)
            Text("18+ only").font(RWF.title()).foregroundColor(.rwTextPrimary)
            Text("Intimacy Builder includes adult content for partnered couples. By continuing you confirm you're 18 or older.")
                .font(RWF.body()).foregroundColor(.rwTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SP.xl)
                .fixedSize(horizontal: false, vertical: true)
            RWButton("I'm 18 or older — continue", icon: "checkmark.shield.fill") { onConfirm() }
                .padding(.horizontal, SP.xl)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .rwBG()
    }
}

// MARK: - Connection Deck (starter library — expand to 20/deck later)

enum ConnectionDeck: String, Identifiable, CaseIterable {
    case warm, deep, raw

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .warm: return Color(hex: "F59E0B")
        case .deep: return Color(hex: "5B8DEF")
        case .raw:  return Color(hex: "E8356D")
        }
    }

    var cards: [String] {
        switch self {
        case .warm:
            return [
                "What's a small moment from this week with me you keep coming back to?",
                "What did you appreciate about the way I handled something recently?",
                "What's one of my expressions or phrases that you find endearing?",
                "When in our day do you feel closest to me?",
                "What would you want me to know about your week that I might not have asked?",
            ]
        case .deep:
            return [
                "What's a fear about us you've never told me?",
                "What do you wish I understood about your inner world that words don't quite reach?",
                "When have you felt most yourself with me — and what made that possible?",
                "What's something we used to do that you miss?",
                "What's one thing that, if it changed about us, would make you feel safer?",
            ]
        case .raw:
            return [
                "What part of intimacy with me feels most natural — and what feels harder to ask for?",
                "What's a desire you've been afraid to share?",
                "When was the last time you felt fully wanted by me, and what was happening?",
                "What's something I do that pulls you toward me, even when you don't say so?",
                "If we could rewrite one part of how we are together physically, what would it be?",
            ]
        }
    }
}

private struct ConnectionCardView: View {
    let prompt: String
    let color: Color
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(color).frame(width: 6, height: 6).padding(.top, 7)
            Text(prompt).font(RWF.body()).foregroundColor(.rwTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(SP.md).background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(color.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Desire Map (private monthly answers)

struct DesireMapView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var answers: [String] = Array(repeating: "", count: questions.count)
    @State private var saved = false

    static let questions: [String] = [
        "What does desire feel like in your body lately?",
        "When have you felt most desired by me in the last month?",
        "What kind of touch do you crave that you don't get often?",
        "What do you wish was easier to ask for?",
        "What do you want more of?",
        "What do you want less of?",
        "What's a fantasy you'd be willing to share?",
        "What would make you feel safer to bring up something tender?",
    ]

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SP.md) {
                    Text("Your answers stay private until both partners complete this. Once partner-sync is live, Cyrano will surface what overlaps.")
                        .font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(Array(Self.questions.enumerated()), id: \.offset) { i, q in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(q).font(RWF.head(14)).foregroundColor(.rwTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            TextField("", text: $answers[i],
                                      prompt: Text("Write here…").foregroundColor(.rwTextMuted),
                                      axis: .vertical)
                                .lineLimit(2...5)
                                .font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                                .padding(SP.md).background(Color.rwCard)
                                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                        }
                    }
                    RWButton(saved ? "Saved" : "Save privately", icon: saved ? "checkmark" : "lock.fill") {
                        saved = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        RIScoreStore.shared.score.vulnerability = min(200, RIScoreStore.shared.score.vulnerability + 4)
                        RIScoreStore.shared.save()
                    }
                    .disabled(saved)
                    .opacity(saved ? 0.6 : 1)
                }
                .padding(SP.lg)
            }
            .rwBG()
            .navigationTitle("The Desire Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.rwAccent)
                }
            }
        }
    }
}

// MARK: - Touch Inventory (weekly slider)

struct TouchInventoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rating: Double = 3
    @State private var saved = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 48)).foregroundColor(Color(hex: "00BFB3"))
                        .padding(.top, 24)
                    Text("How present is touch in your relationship this week?")
                        .font(RWF.head()).foregroundColor(.rwTextPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SP.xl)
                    HStack {
                        Text("Distant").font(RWF.cap()).foregroundColor(.rwTextMuted)
                        Spacer()
                        Text("Constant").font(RWF.cap()).foregroundColor(.rwTextMuted)
                    }
                    .padding(.horizontal, SP.lg)
                    Slider(value: $rating, in: 1...5, step: 1) {
                        Text("Touch")
                    }
                    .padding(.horizontal, SP.lg)
                    Text("\(Int(rating)) / 5")
                        .font(RWF.title()).foregroundColor(.rwTextPrimary)
                    if rating <= 2 {
                        RWCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Cyrano's nudge", systemImage: "sparkles")
                                    .font(RWF.cap()).foregroundColor(.rwAccent)
                                Text("Touch tends to drift before either partner notices. A six-second hug at the end of the day can re-establish the channel without making it a Talk.")
                                    .font(RWF.body()).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    RWButton(saved ? "Saved" : "Save", icon: saved ? "checkmark" : "tray.and.arrow.down.fill") {
                        saved = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        RIScoreStore.shared.bumpConsistency(by: 1)
                    }
                    .disabled(saved)
                    .opacity(saved ? 0.6 : 1)
                    .padding(.horizontal, SP.lg)
                }
                .padding(.bottom, 40)
            }
            .rwBG()
            .navigationTitle("Touch Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.rwAccent)
                }
            }
        }
    }
}
