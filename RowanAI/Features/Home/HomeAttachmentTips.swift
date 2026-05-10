import SwiftUI

// MARK: - Attachment-Style Tips Library (Build 1 — Home Feature 2)
// Five tips per attachment style. The home screen surfaces them in a
// horizontal scroll row keyed to the user's saved style; tapping any tip
// expands into a sheet with a "Try this today" affirmation.

struct AttachmentTip: Identifiable, Hashable {
    let id: Int
    let icon: String
    let headline: String       // 1 sentence — the chip-card line
    let expanded: String       // longer body for the detail sheet
}

enum AttachmentTips {
    // MARK: Library

    static func library(for style: RWUser.AttachmentStyle) -> [AttachmentTip] {
        switch style {
        case .anxiousPreoccupied:  return anxiousPreoccupied
        case .dismissiveAvoidant:  return dismissiveAvoidant
        case .fearfulAvoidant:     return fearfulAvoidant
        case .secure:              return secure
        }
    }

    static let anxiousPreoccupied: [AttachmentTip] = [
        .init(id: 1, icon: "clock.fill",
              headline: "Silence after a message isn't rejection — it's just life. Give it 24 hours.",
              expanded: "Anxious attachment turns ambiguity into evidence — usually evidence of the worst case. Try this: when a delay shows up, set a 24-hour timer in your head and don't reread the thread. Most of the time, life intervened. Letting the silence breathe is what a secure version of you does."),
        .init(id: 2, icon: "questionmark.bubble.fill",
              headline: "Ask yourself: am I responding to what they said, or to my fear?",
              expanded: "The fastest way to short-circuit anxious spirals is the audit question. Read your draft reply and ask: which lines are about what just happened, and which lines are pre-emptive damage control? Cut the second category. What stays is usually closer to who you actually are."),
        .init(id: 3, icon: "hand.raised.fill",
              headline: "The urge to double-text is information about your nervous system, not about them.",
              expanded: "When you feel pulled to send another message before they've replied, the urgency is yours — not theirs. The pull doesn't mean you should act on it. It means your system is asking for reassurance. Try giving it to yourself: do something small that's just for you, then come back."),
        .init(id: 4, icon: "pause.circle.fill",
              headline: "Practice the pause — respond when you're calm, not when you're activated.",
              expanded: "Activated replies almost always sound louder than you intended. Save drafts. Walk a block. Tell Cyrano what you want to say first. Then respond from regulated. The exact same words land differently when they come from a calm place."),
        .init(id: 5, icon: "sparkles",
              headline: "Being interested is attractive. Being anxious about their interest is not.",
              expanded: "Interest pulls people in. Anxiety pushes responsibility onto them — they end up managing your nervous system instead of getting to know you. The lever is to root yourself elsewhere: friends, work you care about, things you'd be doing whether or not they replied. From there, your interest stays interesting."),
    ]

    static let dismissiveAvoidant: [AttachmentTip] = [
        .init(id: 1, icon: "person.fill.checkmark",
              headline: "Letting someone in won't cost you your independence. It might add to it.",
              expanded: "Avoidance often runs on a hidden math: closeness costs autonomy. The math is wrong. Real intimacy expands the territory of your life — more places to be yourself, more people who hold parts of you. Independence and connection aren't a zero-sum trade."),
        .init(id: 2, icon: "hourglass",
              headline: "The discomfort of closeness is temporary. The regret of pushing people away lasts longer.",
              expanded: "The discomfort spike when someone gets close is real — and it always passes. What doesn't pass is the slow accumulation of people you cared about that you never quite let in. Try sitting with the spike for one more conversation than feels comfortable. The relief on the other side is what real attachment feels like."),
        .init(id: 3, icon: "bubble.left.and.bubble.right.fill",
              headline: "Try staying in the conversation one exchange longer than feels comfortable.",
              expanded: "Most avoidant exits happen at a predictable beat — the moment things get a little too real. Just go one round more. Don't change the subject. Don't make a joke to deflect. Stay. The window after that beat is where the actual relationship lives."),
        .init(id: 4, icon: "heart.fill",
              headline: "Vulnerability isn't weakness — it's the thing that makes connection real.",
              expanded: "If you've equated vulnerability with weakness, that's something you learned, often early. The reframe: vulnerability is the highest-skill move in any relationship. The strongest people you know risk being seen. Practice it with one safe person, in one small thing. Skills compound."),
        .init(id: 5, icon: "flame.fill",
              headline: "You don't have to share everything. Start with one true thing.",
              expanded: "Avoidant doesn't mean closed-off forever — it usually means closed-off all-or-nothing. Try a smaller unit. Pick one true thing about how you actually feel right now and say it. Not your life story. Just one true thing. That's the practice."),
    ]

    static let fearfulAvoidant: [AttachmentTip] = [
        .init(id: 1, icon: "arrow.left.and.right",
              headline: "You can want closeness and also be scared of it. Both are true. Neither is wrong.",
              expanded: "Fearful-avoidant lives in the both/and. Wanting closeness and bracing against it isn't a contradiction to fix — it's the lived shape of the pattern. The work isn't to pick a side. The work is to recognize the seesaw and slow it down enough to see what's actually happening."),
        .init(id: 2, icon: "shield.lefthalf.filled",
              headline: "Safety in relationships is built slowly. You don't have to trust all at once.",
              expanded: "Trust isn't a switch. It's earned in small, repeatable ways. Notice who keeps small promises. Notice who repairs after small ruptures. The texture of safety is in those small confirmations — not in grand gestures. You can take this slowly. The right people won't rush you."),
        .init(id: 3, icon: "eye.fill",
              headline: "Notice when you're pulling back. That noticing is already progress.",
              expanded: "The pulling-back motion in fearful-avoidant attachment usually happens before the conscious mind knows it. Naming it as it happens — even silently — interrupts the autopilot. \"I'm pulling back. The person didn't change. Something inside me did.\" That's enough for today."),
        .init(id: 4, icon: "leaf.fill",
              headline: "The pattern isn't you — it's something you learned. It can be unlearned.",
              expanded: "Attachment patterns are adaptations to early environments. They were intelligent then. They may not be useful now. The patterns aren't your identity — they're your software. And software, as it turns out, is rewritable. Slowly, with practice, with relationships that don't replicate the old shape."),
        .init(id: 5, icon: "heart.text.square.fill",
              headline: "One honest moment is worth more than weeks of performing okayness.",
              expanded: "Performing fineness is exhausting and it's also lonely — because no one is meeting the actual you. One honest moment with one person who can hold it is worth more than the months of \"I'm good\" you've been running. Pick that person. Pick that moment."),
    ]

    static let secure: [AttachmentTip] = [
        .init(id: 1, icon: "wave.3.right",
              headline: "Your calm is contagious. The way you show up regulates the people around you.",
              expanded: "Secure attachment functions as a stabilizer in any room you're in. When you're regulated, the people you're with borrow your nervous system. Don't underestimate the gift this is — staying in your steady state is itself a kind of generosity."),
        .init(id: 2, icon: "speaker.wave.2.fill",
              headline: "Practice naming what you need before you need it urgently.",
              expanded: "Even secure attachers can drift into needing-it-urgently mode. The advanced move is preventative communication: saying what you need when it's a 3, not a 9. \"I'd love an evening together this week\" beats the version of that conversation that happens after the resentment has built."),
        .init(id: 3, icon: "questionmark.circle.fill",
              headline: "Genuine curiosity about someone is more attractive than any opening line.",
              expanded: "You already know the basics work. The frontier is depth: questions that surprise people, attention to the things others overlook. Real curiosity doesn't need a script. It just needs you actually paying attention to the specific human in front of you."),
        .init(id: 4, icon: "wrench.adjustable.fill",
              headline: "The best relationships have repair built in — not conflict avoidance.",
              expanded: "Conflict avoidance is a fragile foundation; conflict-with-repair is a durable one. Practice the repair muscle even when small ruptures happen — apologizing cleanly, naming what you missed, asking what would help. Couples that repair predictably outlast couples that avoid."),
        .init(id: 5, icon: "drop.fill",
              headline: "Check in with yourself: are you connecting from fullness or from need today?",
              expanded: "Both can be present, and both are human. But knowing the answer changes the game. Connecting from fullness is generative; connecting from need can be heavy if you don't name it. The question is the practice. Asking honestly is half the work."),
    ]
}

// MARK: - Tips Row View

struct AttachmentTipsRow: View {
    let style: RWUser.AttachmentStyle
    @State private var selected: AttachmentTip? = nil

    private var tips: [AttachmentTip] { AttachmentTips.library(for: style) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: style.icon)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(style.color)
                Text("FOR YOUR \(style.rawValue.uppercased()) STYLE")
                    .font(RWF.micro())
                    .foregroundColor(.rwTextMuted)
                    .tracking(1.4)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(tips) { tip in
                        TipChipCard(tip: tip, accent: style.color) { selected = tip }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
        .sheet(item: $selected) { tip in
            TipDetailSheet(tip: tip, accent: style.color)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct TipChipCard: View {
    let tip: AttachmentTip
    let accent: Color
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Circle().fill(accent.opacity(0.12)).frame(width: 36, height: 36)
                    Image(systemName: tip.icon)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(accent)
                }
                Text(tip.headline)
                    .font(RWF.body(13))
                    .foregroundColor(.rwTextPrimary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Text("Read more").font(RWF.cap(11)).foregroundColor(accent)
                    Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(accent)
                }
            }
            .padding(SP.md)
            .frame(width: 240, height: 168, alignment: .topLeading)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
            .shadow(color: accent.opacity(0.10), radius: 14, x: 0, y: 4)
        }
        .buttonStyle(SBS())
    }
}

private struct TipDetailSheet: View {
    let tip: AttachmentTip
    let accent: Color
    @State private var committed = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SP.lg) {
                ZStack {
                    Circle().fill(accent.opacity(0.12)).frame(width: 64, height: 64)
                    Image(systemName: tip.icon)
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                        .foregroundColor(accent)
                }
                .padding(.top, 4)
                Text(tip.headline)
                    .font(RWF.title(22))
                    .foregroundColor(.rwTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(tip.expanded)
                    .font(RWF.body(16))
                    .foregroundColor(.rwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer().frame(height: 20)
                if committed {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(accent)
                        Text("Locked in for today.").font(RWF.med(15)).foregroundColor(.rwTextPrimary)
                        Spacer()
                    }
                    .padding(SP.md)
                    .background(accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                } else {
                    RWButton("Try this today", icon: "arrow.right") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation { committed = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { dismiss() }
                    }
                }
                Button("Close") { dismiss() }
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                    .frame(maxWidth: .infinity)
                Spacer().frame(height: 40)
            }
            .padding(SP.lg)
        }
        .background(Color.rwBackground.ignoresSafeArea())
    }
}
