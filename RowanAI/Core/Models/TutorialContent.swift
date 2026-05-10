import Foundation

// MARK: - Tutorial Content Models

struct TutorialStep: Identifiable, Hashable {
    let id = UUID()
    let icon: String           // SF Symbol or emoji
    let headline: String
    let body: String
    let tip: String?

    init(icon: String, headline: String, body: String, tip: String? = nil) {
        self.icon = icon
        self.headline = headline
        self.body = body
        self.tip = tip
    }
}

struct Tutorial: Identifiable, Hashable {
    let id: TutorialID
    let title: String
    let estimatedTime: String
    let steps: [TutorialStep]
}

// MARK: - Library
// Static content. Tutorials marked `[stub]` in the comments use plausible
// same-voice defaults — replace these with explicit copy when you have it.

enum TutorialContent {
    static func tutorial(for id: TutorialID) -> Tutorial {
        switch id {
        case .home:               return home
        case .cyrano:             return cyrano
        case .sim:      return sim
        case .firstImpressionLab: return firstImpressionLab
        case .archive:            return archive
        case .datePlanner:        return datePlanner
        case .debrief:            return debrief
        case .relationshipHome:   return relationshipHome
        case .communicationLab:   return communicationLab
        case .rituals:            return rituals
        case .intimacy:           return intimacy
        case .growth:             return growth
        case .riScore:            return riScore
        case .voiceTrainer:       return voiceTrainer
        case .breakupRecovery:    return breakupRecovery
        case .screenshotAnalysis: return screenshotAnalysis
        case .contactPhotos:      return contactPhotos
        case .meetInTheMiddle:    return meetInTheMiddle
        }
    }

    // MARK: - Specified verbatim

    static let home = Tutorial(
        id: .home, title: "Welcome to Rowan", estimatedTime: "30 seconds",
        steps: [
            TutorialStep(icon: "house.fill",
                         headline: "Your daily hub",
                         body: "This is home. Your streak, your RI Score, and Cyrano's daily insight live here. Check in every day to keep your growth going."),
            TutorialStep(icon: "sparkles",
                         headline: "Cyrano knows you",
                         body: "The insight card updates daily based on your attachment style and what you've been working on. It's not generic — it's for you."),
            TutorialStep(icon: "arrow.triangle.2.circlepath",
                         headline: "Your situation, your app",
                         body: "Tap the situation pill to update your status. The app changes with you — single, relationship, or it's complicated."),
            TutorialStep(icon: "lightbulb.fill",
                         headline: "Tips just for you",
                         body: "Scroll the tips row for advice matched to your attachment style. Tap any tip to expand it."),
        ]
    )

    static let cyrano = Tutorial(
        id: .cyrano, title: "Your AI Reply Coach", estimatedTime: "1 minute",
        steps: [
            TutorialStep(icon: "bubble.left.and.bubble.right.fill",
                         headline: "Paste any message",
                         body: "Type or paste a message you received and Cyrano will help you understand it and craft the perfect response."),
            TutorialStep(icon: "photo.on.rectangle",
                         headline: "Drop a screenshot",
                         body: "Tap the photo icon to upload a screenshot of the full conversation. Cyrano reads the actual messages — not just your description."),
            TutorialStep(icon: "circle.grid.cross.fill",
                         headline: "Five tones, your pick",
                         body: "Each generation gives you five versions of the reply across different tones — Flirty, Casual, Funny, Thoughtful, Confident. Pick the one that sounds like you."),
            TutorialStep(icon: "lightbulb.fill",
                         headline: "Exercise suggestions",
                         body: "When Cyrano spots a pattern — like anxiety spiraling or conflict avoidance — it'll suggest a quick exercise to practice. You can always say not now.",
                         tip: "The more context you give Cyrano the better. Mention how long you've been talking, what the vibe is, what you want to happen."),
        ]
    )

    static let sim = Tutorial(
        id: .sim, title: "Practice Real Conversations", estimatedTime: "1 minute",
        steps: [
            TutorialStep(icon: "person.2.wave.2.fill",
                         headline: "Pick your challenge",
                         body: "Choose a personality type, environment, and conversation mode. Each combination trains a different skill."),
            TutorialStep(icon: "gauge.with.dots.needle.50percent",
                         headline: "The engagement meter",
                         body: "Your hidden score tracks how interested the avatar is in real time. It goes up when you're genuine and curious — down when you're surface level or push too hard."),
            TutorialStep(icon: "mic.fill",
                         headline: "Hold to talk",
                         body: "Hold the mic button to speak. Release to send. The avatar responds with voice — just like a real conversation."),
            TutorialStep(icon: "flag.checkered",
                         headline: "Win conditions",
                         body: "Each personality has a specific win condition. Jordan needs to see you're genuine. Casey needs to see you hold your ground. Riley needs patience."),
            TutorialStep(icon: "doc.text.magnifyingglass",
                         headline: "The debrief",
                         body: "After every session Cyrano breaks down what happened, what worked, what to try differently, and how it connects to your attachment style.",
                         tip: "Start with the Social Butterfly or the Overthinker — they're the most forgiving. Save the Confrontational for when you're ready."),
            // Mode appendix — surfaced in the same overlay so users see all
            // three modes during their first The Sim walkthrough.
            TutorialStep(icon: "person.fill",
                         headline: "Single mode",
                         body: "You're meeting a stranger for the first time. Your job: make them want to keep talking to you. Don't perform — be genuinely curious. Silence is okay; rushing to fill it signals insecurity."),
            TutorialStep(icon: "heart.fill",
                         headline: "Relationship mode",
                         body: "The avatar is playing your partner. This isn't small talk — it's the hard stuff. Lead with how you feel, not what they did wrong. Win by creating mutual understanding, not by winning the argument."),
            TutorialStep(icon: "questionmark.circle.fill",
                         headline: "It's Complicated mode",
                         body: "This is for the conversations you've been avoiding. Endings. DTRs. Closure. Clarity is kinder than ambiguity. You can't control how they respond — only how you show up."),
        ]
    )

    static let firstImpressionLab = Tutorial(
        id: .firstImpressionLab, title: "30 Seconds to Make an Impression", estimatedTime: "45 seconds",
        steps: [
            TutorialStep(icon: "timer",
                         headline: "The timer starts when they appear",
                         body: "You have 30 seconds to establish warmth, genuine interest, and a thread worth pulling. That's it."),
            TutorialStep(icon: "list.number",
                         headline: "Four things Cyrano scores",
                         body: "Opening energy, thread quality, authenticity, and whether you made THEM feel interesting."),
            TutorialStep(icon: "arrow.triangle.2.circlepath",
                         headline: "Five rounds per session",
                         body: "Different avatar, different mood, different environment each round. Watch your score climb across the five.",
                         tip: "Don't open with a question. Lead with an observation or a reaction. Questions feel like interviews. Observations feel like connection."),
        ]
    )

    // ARCHIVE — first three steps verbatim from spec, fourth completed in
    // matching voice (the spec was truncated mid-step 4 with "things to ask,
    // things…").
    static let archive = Tutorial(
        id: .archive, title: "Your Relationship CRM", estimatedTime: "1 minute",
        steps: [
            TutorialStep(icon: "person.crop.square.filled.and.at.rectangle",
                         headline: "Every person, one place",
                         body: "Add anyone you're dating, interested in, or want to stay close to. The Archive keeps everything about them in one place."),
            TutorialStep(icon: "photo.on.rectangle",
                         headline: "Photos and screenshots",
                         body: "Add a profile photo, save intel photos, and upload conversation screenshots for Cyrano to analyze."),
            TutorialStep(icon: "calendar",
                         headline: "Date history",
                         body: "Log every date — where you went, how it felt, what you learned. Cyrano uses this for coaching."),
            TutorialStep(icon: "brain.head.profile",
                         headline: "Intel tab",
                         body: "Save things to ask, things to avoid, green flags, red flags, and the small details that make every conversation feel personal — Cyrano pulls from this when you ask for help."),
        ]
    )

    // MARK: - Same-voice defaults (the spec message was truncated)

    static let datePlanner = Tutorial(
        id: .datePlanner, title: "Plan Dates That Land", estimatedTime: "45 seconds",
        steps: [
            TutorialStep(icon: "map.fill",
                         headline: "Search any area",
                         body: "Type a city or neighborhood at the top to anchor the search anywhere — not just where you're standing."),
            TutorialStep(icon: "location.viewfinder",
                         headline: "Meet in the middle",
                         body: "Tap the Midpoint pill to find spots halfway between you and someone in your Archive. We use the geographic midpoint of both addresses."),
            TutorialStep(icon: "sparkles",
                         headline: "AI Picks know who you're seeing",
                         body: "Tag a person in your Archive and Cyrano picks date spots tailored to what you've already learned about them.",
                         tip: "First dates: short and walkable. Coffee or one drink. Save dinner for date two."),
        ]
    )

    static let debrief = Tutorial(
        id: .debrief, title: "Debrief Every Date", estimatedTime: "30 seconds",
        steps: [
            TutorialStep(icon: "doc.text.magnifyingglass",
                         headline: "Right after, while it's fresh",
                         body: "Type a few honest sentences about how the date went. Don't filter — Cyrano only sees what you write."),
            TutorialStep(icon: "checkmark.seal.fill",
                         headline: "Cyrano sorts the signals",
                         body: "Green flags, yellow flags, red flags, plus a recommendation: pursue, wait, or move on."),
            TutorialStep(icon: "arrow.right.circle.fill",
                         headline: "Suggested next message",
                         body: "Cyrano drafts the message to send tonight if it's worth keeping the momentum.",
                         tip: "Trust your gut more than your hopes. If something felt off, that's data."),
        ]
    )

    static let relationshipHome = Tutorial(
        id: .relationshipHome, title: "Your Relationship Hub", estimatedTime: "1 minute",
        steps: [
            TutorialStep(icon: "heart.fill",
                         headline: "We Space",
                         body: "The home base for you and your partner — days together, mood sync, weekly intention, and the small rituals that hold you up over time."),
            TutorialStep(icon: "bubble.left.and.bubble.right.fill",
                         headline: "Talk",
                         body: "Communication Lab — lessons, the Couples Simulator, and practice for the hard conversations before you have them for real."),
            TutorialStep(icon: "sparkles",
                         headline: "Rituals, Intimacy, Grow",
                         body: "Three more tabs: daily and weekly rituals, the intimacy builder, and growth tools (vision board, bucket list, gridlock navigator).",
                         tip: "Pick one ritual and just do it for a week. Consistency builds more connection than intensity."),
        ]
    )

    static let communicationLab = Tutorial(
        id: .communicationLab, title: "Couples Communication Lab", estimatedTime: "45 seconds",
        steps: [
            TutorialStep(icon: "book.fill",
                         headline: "Ten lessons, real frameworks",
                         body: "Gottman's Four Horsemen, repair attempts, bids for connection — each lesson is short and practical. First three are free."),
            TutorialStep(icon: "person.2.fill",
                         headline: "Couples Simulator",
                         body: "Describe a scenario. Cyrano writes the exact opener you could say tonight, calibrated to your real relationship context."),
            TutorialStep(icon: "exclamationmark.bubble.fill",
                         headline: "Difficult Conversation Simulator",
                         body: "Practice the conversation you've been avoiding before you have it for real. Currently a Build 2 preview."),
        ]
    )

    static let rituals = Tutorial(
        id: .rituals, title: "Rituals That Stick", estimatedTime: "30 seconds",
        steps: [
            TutorialStep(icon: "sun.max.fill",
                         headline: "Daily",
                         body: "Morning intention, evening debrief, six-second-kiss reminder. Tiny acts that compound."),
            TutorialStep(icon: "calendar",
                         headline: "Weekly",
                         body: "State of Us check-in, appreciation practice, and a research-backed growth challenge — one per week, library of 52."),
            TutorialStep(icon: "moon.stars.fill",
                         headline: "Meditations",
                         body: "Loving-kindness, breathwork for conflict, gratitude, and the worry offload. Apple TTS free; ElevenLabs voice with Pro.",
                         tip: "If you can only do one thing: do the evening debrief. Three short answers, end the day connected."),
        ]
    )

    static let intimacy = Tutorial(
        id: .intimacy, title: "Intimacy Builder", estimatedTime: "30 seconds",
        steps: [
            TutorialStep(icon: "lock.shield.fill",
                         headline: "18+ space",
                         body: "Adult content for partnered couples. By entering you're confirming you're 18 or older."),
            TutorialStep(icon: "rectangle.stack.fill",
                         headline: "Connection Cards",
                         body: "Three decks — Warm, Deep, Raw. Both partners see the same card; answer privately, share when ready."),
            TutorialStep(icon: "map.fill",
                         headline: "Desire Map + Touch Inventory",
                         body: "Monthly desire questions, a weekly touch slider. Cyrano notices when things drift and gently nudges."),
        ]
    )

    static let growth = Tutorial(
        id: .growth, title: "Growth Together", estimatedTime: "30 seconds",
        steps: [
            TutorialStep(icon: "sparkles.rectangle.stack.fill",
                         headline: "Vision Board",
                         body: "What does this relationship look like in one year? Five? Both contribute privately; Cyrano synthesizes."),
            TutorialStep(icon: "checkmark.square.fill",
                         headline: "Bucket List",
                         body: "Tag items by category — Adventure, Creative, Quiet, Romantic, Challenging. Pick one a month and actually do it."),
            TutorialStep(icon: "compass.drawing",
                         headline: "Gridlock Navigator",
                         body: "Most recurring fights are about meaning, not facts. Describe the fight and Cyrano shows you what's underneath it for each of you.",
                         tip: "Couples that repair predictably outlast couples that avoid. Practice the repair muscle on small things."),
        ]
    )

    static let riScore = Tutorial(
        id: .riScore, title: "Your Relational Intelligence Score", estimatedTime: "30 seconds",
        steps: [
            TutorialStep(icon: "chart.bar.fill",
                         headline: "Six dimensions",
                         body: "Presence, Attunement, Repair, Vulnerability, Curiosity, Consistency. Each scored 0-200, tracked over time."),
            TutorialStep(icon: "arrow.up.right",
                         headline: "Built by what you do",
                         body: "The Sim sessions raise Curiosity and Attunement. Daily rituals raise Consistency. Voice Trainer raises Presence. The score follows your practice."),
            TutorialStep(icon: "lightbulb.fill",
                         headline: "Where you're weakest is where you grow fastest",
                         body: "Your home insight card already tells you which dimension to focus on this week.",
                         tip: "Don't optimize for the total — optimize for the lowest dimension. That's where the biggest gains live."),
        ]
    )

    static let voiceTrainer = Tutorial(
        id: .voiceTrainer, title: "Voice Confidence Trainer", estimatedTime: "30 seconds",
        steps: [
            TutorialStep(icon: "waveform",
                         headline: "Three exercises",
                         body: "Presence Check (filler words + pace), Warmth Calibration (tone of voice), Silence Practice (the 5-second hold)."),
            TutorialStep(icon: "headphones",
                         headline: "Hear yourself",
                         body: "Most people discover their \"warm\" sounds like their \"neutral.\" Hearing the difference is half the work."),
            TutorialStep(icon: "calendar.badge.clock",
                         headline: "Daily, brief",
                         body: "Each exercise is 2-5 minutes. Available daily. Full feature ships in Build 3 — Presence Check is live now.",
                         tip: "If you can only practice one thing: the silence. Hold five seconds after saying something real."),
        ]
    )

    static let breakupRecovery = Tutorial(
        id: .breakupRecovery, title: "Breakup Recovery", estimatedTime: "30 seconds",
        steps: [
            TutorialStep(icon: "leaf.fill",
                         headline: "A different kind of mode",
                         body: "Less coach, more steady presence. Dating features hide. Cyrano's tone shifts — less advice, more acknowledgment."),
            TutorialStep(icon: "checkmark.circle.fill",
                         headline: "Daily check-ins",
                         body: "One question a day. Thirty seconds. Skippable. Cyrano responds with one sentence — never a lecture."),
            TutorialStep(icon: "map.fill",
                         headline: "The grief timeline",
                         body: "Shock, bargaining, the fog, anger, the hollow, gradual return. Not linear, not a checklist — but knowing the terrain helps.",
                         tip: "You're not behind. There's no timeline you're supposed to be on."),
        ]
    )

    static let screenshotAnalysis = Tutorial(
        id: .screenshotAnalysis, title: "Drop a Screenshot", estimatedTime: "20 seconds",
        steps: [
            TutorialStep(icon: "photo.on.rectangle",
                         headline: "Upload the actual conversation",
                         body: "Tap the photo icon next to the input. Cyrano reads the real messages, response times, and tone — not just your description."),
            TutorialStep(icon: "eye.fill",
                         headline: "What Cyrano sees",
                         body: "Word choice, pauses, the shape of the back-and-forth. Coaching that references what's actually there beats coaching from memory.",
                         tip: "One screenshot per message. If the thread is long, send a screenshot of the most recent exchange — that's usually what matters."),
        ]
    )

    static let contactPhotos = Tutorial(
        id: .contactPhotos, title: "Photos in the Archive", estimatedTime: "30 seconds",
        steps: [
            TutorialStep(icon: "person.crop.circle.badge.checkmark",
                         headline: "Profile + intel photos",
                         body: "Set a profile photo on each contact. Add intel photos — screenshots, photos from dates, things you want to remember them by."),
            TutorialStep(icon: "camera.fill",
                         headline: "Capture or import",
                         body: "Take a photo from inside Rowan or pick from your library. Long-press any thumbnail to caption it or delete it."),
            TutorialStep(icon: "rectangle.stack.fill",
                         headline: "Photos tab",
                         body: "Every photo for one contact lives in the Photos tab — full-screen grid, tap to view, swipe to browse.",
                         tip: "Caption the screenshots that matter. \"The text where they ghosted\" is a useful note three months later."),
        ]
    )

    static let meetInTheMiddle = Tutorial(
        id: .meetInTheMiddle, title: "Meet in the Middle", estimatedTime: "20 seconds",
        steps: [
            TutorialStep(icon: "location.viewfinder",
                         headline: "Geographic midpoint",
                         body: "We compute the lat/lng midpoint between your location and a contact's saved address, then center the map there."),
            TutorialStep(icon: "person.crop.circle.fill",
                         headline: "Save their location first",
                         body: "Add a location on a contact's profile (it autocompletes via Apple Maps). Once saved, they show up in the Midpoint picker.",
                         tip: "Best for early dates when neither person wants to commit to the other's neighborhood."),
        ]
    )
}
