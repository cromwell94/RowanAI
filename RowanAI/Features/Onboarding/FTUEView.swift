import SwiftUI

// MARK: - First Time User Experience (FTUE)
//
// 12-slide immersive tour shown immediately after onboarding completes for the
// first time. Persists `hasSeenFTUE` to UserDefaults so it never re-shows
// unprompted. Restart entry point lives in Settings.
//
// Realistic scope note: each slide uses a stylized icon-and-pills card rather
// than a fully-animated mock of every feature's UI — full feature mocks would
// be many thousand lines per slide and a separate pass.

@Observable
@MainActor
final class FTUEManager {
    static let shared = FTUEManager()

    private let key = "hasSeenFTUE"

    var hasSeen: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// Set by the root view to trigger the tour the next time the app gets a
    /// chance to render it. Used by both the onboarding-complete handoff and
    /// the Settings restart action.
    var shouldShow: Bool = false

    func markSeen() {
        hasSeen = true
        shouldShow = false
    }

    func restart() {
        hasSeen = false
        shouldShow = true
    }
}

// MARK: - Slide Data

struct FTUESlide: Identifiable {
    let id = UUID()
    let icon: String
    let accent: Color
    let headline: String
    let body: String
    let pills: [String]
    let isFinal: Bool

    init(icon: String, accent: Color, headline: String, body: String,
         pills: [String] = [], isFinal: Bool = false) {
        self.icon = icon
        self.accent = accent
        self.headline = headline
        self.body = body
        self.pills = pills
        self.isFinal = isFinal
    }
}

enum FTUEContent {
    static let pink = Color(hex: "E8356D")
    static let teal = Color(hex: "00BFB3")
    static let amber = Color(hex: "C0A020")
    static let blue = Color(hex: "5B8DEF")
    static let purple = Color(hex: "8E44AD")
    static let coral = Color(hex: "FF6B6B")

    static let slides: [FTUESlide] = [
        FTUESlide(
            icon: "sparkles",
            accent: pink,
            headline: "Welcome to Rowan",
            body: "Your personal relational intelligence coach. In the next 60 seconds we'll show you everything Rowan can do — you can always come back to this tour from Settings."
        ),
        FTUESlide(
            icon: "bubble.left.and.bubble.right.fill",
            accent: pink,
            headline: "Cyrano — Your AI Coach",
            body: "Paste any message you received. Cyrano reads it, understands the dynamic, and gives you 3 replies in different tones. Or drop a screenshot — Cyrano reads the actual conversation.",
            pills: ["5 Tones", "Screenshot Analysis", "Exercise Suggestions"]
        ),
        FTUESlide(
            icon: "text.bubble.fill",
            accent: blue,
            headline: "Fill Me In",
            body: "Build out a full conversation with I Said / They Said columns. Cyrano reads the whole thing and gives you a complete analysis — the dynamic, what's working, what to watch, and exactly what to say next."
        ),
        FTUESlide(
            icon: "person.crop.rectangle.fill",
            accent: purple,
            headline: "Dating App Profile Coach",
            body: "Upload your photos and Cyrano scores them. Get 3 versions of every prompt. Write a bio that sounds like you. Generate opening messages for any match.",
            pills: ["Photo Scoring", "Prompt Coach", "Bio Writer", "Openers"]
        ),
        FTUESlide(
            icon: "bubble.left.and.bubble.right.fill",
            accent: pink,
            headline: "Face to Face Sim",
            body: "Practice real conversations with AI avatars before they happen. 6 personalities, 5 environments, 3 modes. The engagement meter tracks how interested the avatar is in real time. Cyrano debriefs you after every session.",
            pills: ["6 Avatars", "Engagement Meter", "Full Debrief", "Single · Relationship · Complicated"]
        ),
        FTUESlide(
            icon: "timer",
            accent: coral,
            headline: "First Impression Lab",
            body: "30 seconds. One avatar. One chance. Practice the first 30 seconds of a conversation — the moment that decides everything. 5 rounds per session, score improves each time."
        ),
        FTUESlide(
            icon: "archivebox.fill",
            accent: teal,
            headline: "Your Relationship Archive",
            body: "Everyone you're dating or interested in, in one place. Photos, conversation history across every platform, date logs, intel notes, and a living analysis that updates as you add more. Import directly from your iPhone Contacts.",
            pills: ["Multi-Platform", "Living Analysis", "Import Contacts", "Cyrano's Read"]
        ),
        FTUESlide(
            icon: "map.fill",
            accent: blue,
            headline: "Date Planner",
            body: "Set the scene first — who it's with, what occasion, what vibe, where, and your budget. Cyrano suggests perfect date spots tailored to all of it. Meet in the middle, search near them, or find spots near you.",
            pills: ["Set the Scene", "Meet in the Middle", "AI Picks", "Wishlist"]
        ),
        FTUESlide(
            icon: "heart.fill",
            accent: amber,
            headline: "Relationship Mode",
            body: "For couples. Daily rituals, mood sync, the 6-second kiss reminder, couples communication lab, intimacy builder, and growth tools. Switch on when you're in a relationship — it all changes to warm amber.",
            pills: ["Rituals", "Communication Lab", "Intimacy Builder", "Chemistry Report"]
        ),
        FTUESlide(
            icon: "chart.line.uptrend.xyaxis",
            accent: teal,
            headline: "Your Relational Intelligence Score",
            body: "Track your growth across 6 dimensions — Presence, Attunement, Repair, Vulnerability, Curiosity, Consistency. Every session, ritual, and conversation feeds your score. Watch it climb over time."
        ),
        FTUESlide(
            icon: "heart.slash.fill",
            accent: purple,
            headline: "Breakup Recovery Mode",
            body: "Going through something hard? Switch to Recovery Mode. All dating features step back. Daily check-ins, a grief timeline, pattern analysis, and a readiness score for when you're actually ready to re-enter — not when anyone else says you should be."
        ),
        FTUESlide(
            icon: "crown.fill",
            accent: amber,
            headline: "Try Pro Free for 7 Days",
            body: "Unlimited Cyrano, all 6 avatars, full RI Score tracking, Relationship Mode, Voice Trainer, Weekly Connection Report, and more. Or stay free — every core feature works without paying.",
            pills: ["Unlimited Cyrano", "All Avatars", "Relationship Mode", "Voice Trainer"],
            isFinal: true
        )
    ]
}

// MARK: - Tour View

struct FTUEView: View {
    let onFinish: () -> Void

    @State private var index = 0
    @State private var showPaywall = false

    private var slides: [FTUESlide] { FTUEContent.slides }

    var body: some View {
        ZStack {
            backdrop
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, SP.lg)
                    .padding(.top, 4)

                TabView(selection: $index) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { i, slide in
                        FTUESlideView(
                            slide: slide,
                            slideIndex: i,
                            totalCount: slides.count,
                            onPrimary: { primaryAction() },
                            onStartFree: slide.isFinal ? { complete() } : nil,
                            onStartTrial: slide.isFinal ? { showPaywall = true } : nil
                        )
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea(edges: .bottom)

                progressDots
                    .padding(.bottom, 18)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPaywall, onDismiss: { complete() }) {
            PaywallView(reason: .upgrade)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text("\(index + 1) of \(slides.count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.white.opacity(0.10))
                .clipShape(Capsule())
            Spacer()
            Button {
                complete()
            } label: {
                Text("Skip Tour")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Progress dots

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<slides.count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Color.white : Color.white.opacity(0.25))
                    .frame(width: i == index ? 18 : 6, height: 6)
                    .animation(.spring(response: 0.4), value: index)
            }
        }
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        let accent = slides[safe: index]?.accent ?? FTUEContent.pink
        return ZStack {
            Color(hex: "06000F")
            RadialGradient(
                colors: [accent.opacity(0.30), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 600
            )
            RadialGradient(
                colors: [FTUEContent.teal.opacity(0.18), .clear],
                center: .bottom,
                startRadius: 0,
                endRadius: 500
            )
        }
        .animation(.easeInOut(duration: 0.6), value: index)
    }

    // MARK: - Actions

    private func primaryAction() {
        if index < slides.count - 1 {
            withAnimation(.spring(response: 0.4)) { index += 1 }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else {
            complete()
        }
    }

    private func complete() {
        FTUEManager.shared.markSeen()
        onFinish()
    }
}

// MARK: - Single slide

private struct FTUESlideView: View {
    let slide: FTUESlide
    let slideIndex: Int
    let totalCount: Int
    let onPrimary: () -> Void
    let onStartFree: (() -> Void)?
    let onStartTrial: (() -> Void)?

    @State private var appeared = false

    var body: some View {
        VStack(spacing: SP.lg) {
            Spacer()

            // Icon disc
            ZStack {
                Circle()
                    .fill(slide.accent.opacity(0.20))
                    .frame(width: 140, height: 140)
                Circle()
                    .stroke(slide.accent.opacity(0.40), lineWidth: 1)
                    .frame(width: 160, height: 160)
                Image(systemName: slide.icon)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [slide.accent, slide.accent.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 14) {
                Text(slide.headline)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SP.lg)

                Text(slide.body)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, SP.xl)
                    .fixedSize(horizontal: false, vertical: true)

                if !slide.pills.isEmpty {
                    pillStrip
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)

            Spacer()

            actionRow
                .padding(.horizontal, SP.xl)
                .padding(.bottom, 14)
        }
        .onAppear {
            appeared = false
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.05)) {
                appeared = true
            }
        }
    }

    private var pillStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(slide.pills, id: \.self) { pill in
                    Text(pill)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                }
            }
            .padding(.horizontal, SP.xl)
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        if slide.isFinal {
            VStack(spacing: 10) {
                if let onStartTrial = onStartTrial {
                    Button {
                        onStartTrial()
                    } label: {
                        Text("Start Free Trial →")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(SBS())
                }
                if let onStartFree = onStartFree {
                    Button {
                        onStartFree()
                    } label: {
                        Text("Start with Free →")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(SBS())
                }
            }
        } else {
            Button(action: onPrimary) {
                HStack(spacing: 6) {
                    Text(slideIndex == 0 ? "Show Me Everything" : "Next")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LinearGradient.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(SBS())
        }
    }
}

// MARK: - Tiny array safety helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
