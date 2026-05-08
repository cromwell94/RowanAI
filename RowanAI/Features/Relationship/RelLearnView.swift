import SwiftUI

// MARK: - Learn View

struct RelLearnView: View {
    @State private var selected: LearnSection? = nil

    let sections: [LearnSection] = [
        LearnSection(
            title: "Warning Signs of Abuse",
            icon: "exclamationmark.triangle.fill",
            color: Color(hex: "E8356D"),
            tag: "Important",
            articles: [
                Article(title: "What is emotional abuse?",
                    content: """
Emotional abuse is a pattern of behaviour designed to control, manipulate, or undermine someone's sense of self-worth. Unlike physical abuse, it leaves no visible marks — which makes it harder to recognise and easier to dismiss.

It can include: constant criticism, humiliation, name-calling, ignoring or stonewalling as punishment, threatening, blaming, and making someone feel like everything is their fault.

The key word is "pattern." Everyone has bad days. Emotional abuse is consistent, escalating, and always brings you back to feeling small.

If you often feel like you're walking on eggshells, like you can't do anything right, or like you need permission to see people or make decisions — that's worth paying attention to.
"""),
                Article(title: "Love bombing vs genuine affection",
                    content: """
Love bombing feels incredible at first — intense attention, constant compliments, big gestures, declarations of love unusually early. It can feel like finally being truly seen.

The difference between love bombing and genuine affection:
• Love bombing is overwhelming and fast. It creates obligation and dependency before trust has been built.
• Genuine affection builds gradually and feels warm, not urgent.
• Love bombing often comes with subtle control — "I just love you so much I want you all to myself."
• After love bombing comes a shift — the attention withdraws, replaced by criticism or coldness. This is the cycle beginning.

Healthy love doesn't rush. Someone who genuinely cares for you respects that real connection takes time.
"""),
                Article(title: "Coercive control — what it looks like",
                    content: """
Coercive control is a pattern of behaviour that strips someone of their independence. It's often mistaken for protectiveness or love.

Signs include:
• Monitoring your phone, location, or social media
• Isolating you from friends and family ("they don't understand us")
• Controlling finances — limiting access to money or making you account for every purchase
• Making decisions for you — what to wear, eat, who to see
• Using guilt to prevent you from doing things independently
• Threatening consequences if you don't comply

Coercive control is recognised as abuse in many countries regardless of whether physical violence occurs. It is serious. If this sounds familiar, you are not overreacting.

The National DV Hotline (1-800-799-7233) can help you understand your situation safely.
"""),
                Article(title: "Gaslighting — when reality gets questioned",
                    content: """
Gaslighting is when someone makes you doubt your own memory, perception, or sanity. The name comes from a 1944 film where a husband manipulates his wife into thinking she's losing her mind.

It sounds like:
• "That never happened."
• "You're too sensitive."
• "You're imagining things."
• "Everyone agrees with me, not you."
• "You always do this — you're so dramatic."

Over time, gaslighting makes you stop trusting your own instincts. You start apologising for things you didn't do. You feel confused, anxious, and dependent on the person who's confusing you.

Your feelings and your memories are valid. If someone consistently makes you feel like your reality is wrong — that's a pattern worth taking seriously.
"""),
                Article(title: "The cycle of abuse",
                    content: """
Abuse in relationships often follows a recognisable cycle. Understanding it doesn't mean excusing it — it means recognising it.

The cycle typically has four stages:

1. Tension building — small incidents, walking on eggshells, anxiety escalating
2. Incident — the abusive behaviour occurs (verbal, emotional, physical, sexual)
3. Reconciliation — apologies, promises to change, affection, excuses ("I only did it because...")
4. Calm — the "honeymoon phase," things feel normal, hope returns

The cycle repeats. Each time, the reconciliation phase gets shorter and the incidents often escalate.

The hardest part: the person you love during the calm phase is real. Which is why leaving is so complicated. If you're in this cycle, you deserve support — not judgement. The National DV Hotline (1-800-799-7233) offers free, confidential help.
"""),
                Article(title: "Healthy jealousy vs controlling jealousy",
                    content: """
A small amount of jealousy in a relationship is human. The question is what someone does with it.

Healthy jealousy: "I felt a bit insecure when you mentioned your ex — can we talk about it?" They express the feeling and work through it. They don't punish you.

Controlling jealousy: "You can't go there. You can't wear that. Why are you talking to them? Show me your phone." They act on the jealousy by restricting your freedom.

Controlling jealousy is often framed as love ("I just care about you so much"). But love doesn't require surveillance. Trust is the foundation — jealousy that seeks to control is about power, not love.

If your partner's jealousy makes you change your behaviour out of fear rather than care, that's the line.
""")
            ]),

        LearnSection(
            title: (AuthService.shared.currentUser?.isFirstRelationship == true) ? "Starting Out: Your First Relationship" : "Building Something Real",
            icon: "heart.fill",
            color: Color(hex: "E8356D"),
            tag: (AuthService.shared.currentUser?.isFirstRelationship == true) ? "First Relationship" : "Guide",
            articles: [
                Article(title: "What to expect in the first few months",
                    content: """
The first few months of a relationship are often called the honeymoon phase — everything feels exciting, your partner seems almost perfect, and you want to spend all your time together.

This is real, but it's also chemistry. Dopamine, serotonin, norepinephrine — your brain is doing something genuinely different during early love.

What's normal:
• Thinking about them constantly
• Wanting to text all day
• Everything feeling significant
• Feeling unusually happy

What's also normal and doesn't mean it's failing:
• The intensity settling after 3-6 months
• Small irritations appearing
• Needing your own time sometimes
• Feeling nervous about where it's going

The honeymoon phase ending isn't the relationship ending. It's where the real relationship begins.
"""),
                Article(title: "Keeping your identity in a relationship",
                    content: """
One of the most common mistakes in first relationships is losing yourself. You start spending all your time with your partner. Your friends hear from you less. Your hobbies fall away. You start defining yourself through them.

This feels loving. It can also be the beginning of unhealthy enmeshment.

Healthy relationships have two whole people in them — not one and a half.

How to maintain yourself:
• Keep seeing your friends, even when you'd rather be with your partner
• Keep doing the things you loved before the relationship
• Have opinions, plans, and a life that exists independently
• Your partner should add to your life, not become your whole life

The people who are most attractive in relationships are the ones who have their own thing going on. And you'll be a better partner when you're a full person, not just half of a couple.
"""),
                Article(title: "Conflict — it's not a sign something is wrong",
                    content: """
If you've never been in a relationship before, your first argument can feel catastrophic. "Maybe we're not right for each other." "This is a sign." "Maybe I should end it."

It's almost certainly not.

All couples argue. The research of Dr. John Gottman shows it's not whether couples fight — it's how they fight that determines relationship health.

Healthy conflict:
• Both people feel heard
• Neither attacks the other's character
• You argue about the issue, not become contemptuous
• There's repair — someone tries to de-escalate
• You come back together after

Unhealthy conflict:
• Criticism of who they are as a person
• Contempt ("you're pathetic")
• Defensiveness without listening
• Stonewalling — shutting down completely

Learning to fight fairly is a skill. It takes time. Your first few arguments are you learning how you both handle conflict — not proof the relationship is broken.
"""),
                Article(title: "Talking about exclusivity",
                    content: """
One of the most anxious conversations in early relationships — "are we official?"

There's no perfect timing but some principles:

• If you're sleeping with someone and you want to be exclusive, you're allowed to say that. It's not too much to ask.
• Exclusivity is a conversation, not an assumption. Don't assume — have the conversation.
• If someone avoids the conversation repeatedly, that's information.
• "What are we?" is a valid question. Anyone who makes you feel ridiculous for asking it is not treating you well.

The conversation doesn't have to be dramatic. "I really like spending time with you. I'm not interested in seeing anyone else — I wanted to check where you're at." Simple, direct, self-respecting.

You're allowed to want a clear answer. You're also allowed to leave if one isn't forthcoming.
"""),
                Article(title: "When the honeymoon phase ends",
                    content: """
Around 3-6 months in, something shifts. The intensity settles. You might notice small things that bother you. You might feel less constantly happy and more just... normal.

This is not a red flag. This is what real love actually feels like.

The early stage is infatuation — biochemical, automatic, and temporary by design. The second stage is where attachment builds. This is deeper, quieter, and more sustainable.

Signs the second stage is healthy:
• You feel comfortable being yourself, not just your best self
• You can have a boring evening together and it's fine
• You can disagree and come back to each other
• The care is still there, just less frantic

What sometimes happens: one person's feelings settle while the other is still in the infatuation stage. This can feel like rejection or cooling off. If this happens — talk about it. Don't assume.

The relationship isn't dying. It's maturing.
"""),
                Article(title: "Sex, consent, and communication",
                    content: """
Consent is ongoing, enthusiastic, and can be withdrawn at any time. This applies to both people in a relationship, always.

"We've done it before" is not consent. Silence is not consent. Not saying no is not consent. Consent is an active, enthusiastic yes — verbal or clearly communicated.

In first relationships:
• It's okay to want to wait. It's okay to not want to wait. Both are valid.
• You are never obligated to do anything you're not comfortable with — regardless of how long you've been together or what has happened before.
• If your partner makes you feel guilty, pressured, or like you owe them — that's a problem.
• Communication about what you want and don't want is not awkward — it's necessary.

If something happened that you didn't consent to, it was not your fault. The National Sexual Assault Hotline is 1-800-656-4673.
""")
            ]),

        LearnSection(
            title: "What Healthy Looks Like",
            icon: "checkmark.seal.fill",
            color: Color(hex: "00BFB3"),
            tag: "Foundation",
            articles: [
                Article(title: "The signs of a genuinely healthy relationship",
                    content: """
Healthy relationships don't look like the movies. They're less dramatic and more consistent.

Signs you're in a healthy relationship:
• You feel safe being yourself — not your best self, your actual self
• Conflict gets resolved, not avoided or exploded
• You trust each other without needing to check or verify
• You both have lives outside the relationship
• Your friends and family like your partner and vice versa
• You feel better about yourself, not worse, because of this relationship
• You can say no to things and have it respected
• Apologies happen and mean something
• You feel like equals

The most important one: you feel free. Not monitored, not walking on eggshells, not moulding yourself to keep the peace. Free to be honest, free to take up space, free to be imperfect.
"""),
                Article(title: "Bids for connection — Gottman's most important concept",
                    content: """
Dr. John Gottman's research identified something called "bids for connection" — small moments where one partner reaches out for attention, affirmation, or engagement.

A bid can be:
• "Look at that sunset."
• "I had a weird day."
• Reaching for your hand.
• Sending a funny meme.

The response to bids predicts relationship success more accurately than almost anything else.

Turning toward: "Oh wow, beautiful." / "What happened?" — engaging with the bid.
Turning away: ignoring it, staying on your phone, not responding.
Turning against: "You're always interrupting me."

Couples who stay together turn toward each other's bids around 86% of the time. Couples who divorce turn toward them about 33% of the time.

The small moments matter more than the grand gestures.
"""),
                Article(title: "Maintaining attraction over time",
                    content: """
One of the fears in a long relationship is that attraction fades. It can. But it doesn't have to.

What kills attraction:
• Total predictability — no mystery, no surprise
• Losing individual identity — becoming one merged unit
• Taking each other for granted
• Stopping investing in yourself
• Letting novelty die completely

What maintains attraction:
• Maintaining some mystery — not everything needs to be shared
• Having your own interests, friends, and growth
• Genuine curiosity about your partner — people change, keep learning them
• Introducing new experiences together
• Physical affection that isn't always sexual — touch, presence, closeness
• Admiration — actively looking for what you appreciate about them

Esther Perel's insight: desire needs space. You can't want what you already have completely. Maintaining some separateness — not distance, but distinctness — keeps the spark alive.
""")
            ])
    ]

    var body: some View {
        if let section = selected {
            ArticleListView(section: section) { selected = nil }
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Learn").font(RWF.display(28)).foregroundColor(.rwTextPrimary)
                        Text("Honest, clear information about relationships — the healthy and the harmful.")
                            .font(RWF.body()).foregroundColor(.rwTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)

                    ForEach(sections) { section in
                        Button { withAnimation { selected = section } } label: {
                            HStack(spacing: 14) {
                                Image(systemName: section.icon)
                                    .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                                    .frame(width: 52, height: 52).background(section.color)
                                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(spacing: 8) {
                                        Text(section.title).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                                        Text(section.tag).font(RWF.micro()).foregroundColor(section.color)
                                            .padding(.horizontal, 7).padding(.vertical, 3)
                                            .background(section.color.opacity(0.1)).clipShape(Capsule())
                                    }
                                    Text("\(section.articles.count) articles").font(RWF.cap()).foregroundColor(.rwTextSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
                            }
                            .padding(SP.md).background(Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
                            .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
                        }
                        .buttonStyle(SBS())
                    }

                    CrisisQuickAccess()
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, SP.lg).padding(.top, 12)
            }
        }
    }
}

struct LearnSection: Identifiable {
    let id = UUID()
    let title: String; let icon: String; let color: Color; let tag: String; let articles: [Article]
}

struct Article: Identifiable {
    let id = UUID()
    let title: String; let content: String
}

struct ArticleListView: View {
    let section: LearnSection; let onBack: () -> Void
    @State private var selected: Article? = nil

    var body: some View {
        if let article = selected {
            ArticleView(article: article, color: section.color) { selected = nil }
        } else {
            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.rwTextPrimary).frame(width: 36, height: 36)
                            .background(Color.rwSurface).clipShape(Circle())
                    }
                    Spacer()
                    Text(section.title).font(RWF.head()).foregroundColor(.rwTextPrimary).lineLimit(1)
                    Spacer()
                    Spacer().frame(width: 36)
                }
                .padding(.horizontal, SP.lg).padding(.vertical, 14)
                RWLine()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(section.articles) { article in
                            Button { withAnimation { selected = article } } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: section.icon)
                                        .font(.system(size: 14, weight: .semibold)).foregroundColor(section.color)
                                        .frame(width: 36, height: 36).background(section.color.opacity(0.1))
                                        .clipShape(Circle())
                                    Text(article.title).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
                                }
                                .padding(SP.md).background(Color.rwCard)
                                .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                                .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
                                .shadow(color: Color.rwShadow, radius: 6, x: 0, y: 2)
                            }
                            .buttonStyle(SBS())
                        }
                        CrisisQuickAccess()
                        Spacer().frame(height: 80)
                    }
                    .padding(.horizontal, SP.lg).padding(.top, 12)
                }
            }
            .rwBG()
        }
    }
}

struct ArticleView: View {
    let article: Article; let color: Color; let onBack: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.rwTextPrimary).frame(width: 36, height: 36)
                        .background(Color.rwSurface).clipShape(Circle())
                }
                Spacer()
                Spacer().frame(width: 36)
            }
            .padding(.horizontal, SP.lg).padding(.vertical, 14)
            RWLine()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SP.lg) {
                    Text(article.title).font(RWF.display(26)).foregroundColor(.rwTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    Text(article.content).font(RWF.body(16)).foregroundColor(.rwTextPrimary)
                        .fixedSize(horizontal: false, vertical: true).lineSpacing(6)

                    CrisisQuickAccess()
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, SP.lg).padding(.top, 12)
            }
        }
        .rwBG()
    }
}
