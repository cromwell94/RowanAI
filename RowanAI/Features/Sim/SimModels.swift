import Foundation
import SwiftUI

// MARK: - Sim Mode (Build 1 — three conversation modes)
// The personalities and environments stay the same across modes; what changes
// is the *scenario* the avatar is playing — stranger, partner, or someone
// from the user's complicated past — plus the win condition and the lens
// Cyrano uses to brief and debrief.

enum SimMode: String, Codable, CaseIterable, Identifiable {
    case single        = "Single"
    case relationship  = "Relationship"
    case complicated   = "It's Complicated"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .single:        return "Single"
        case .relationship:  return "Relationship"
        case .complicated:   return "Complicated"
        }
    }

    var headerLabel: String {
        switch self {
        case .single:        return "Single Mode"
        case .relationship:  return "Relationship Mode"
        case .complicated:   return "It's Complicated"
        }
    }

    var icon: String {
        switch self {
        case .single:        return "person.fill"
        case .relationship:  return "heart.fill"
        case .complicated:   return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .single:        return .rwAccent
        case .relationship:  return .rwAmber
        case .complicated:   return Color(hex: "6B7FD7")
        }
    }

    static func auto(for status: RelationshipStatus?) -> SimMode {
        switch status {
        case .relationship: return .relationship
        case .complicated:  return .complicated
        case .single, .none: return .single
        }
    }

    /// Win-condition framing — appended to the avatar system prompt and shown
    /// to the user in the brief.
    var winCondition: String {
        switch self {
        case .single:
            return "Win condition: get the avatar genuinely interested in continuing the conversation."
        case .relationship:
            return "Win condition: the user gets you to feel heard AND heard you back — a moment of genuine mutual understanding."
        case .complicated:
            return "Win condition: the user handles the situation with emotional intelligence — says what needs to be said, hears what needs to be heard, and leaves the conversation with dignity intact on both sides."
        }
    }

    /// Mode-specific overlay appended to the personality system prompt. Replaces
    /// the dating-stranger framing with partner / complicated-past framing.
    func systemPromptOverlay(partnerName: String?) -> String {
        switch self {
        case .single:
            return ""
        case .relationship:
            let p = partnerName?.isEmpty == false ? partnerName! : "your partner"
            return """

            RELATIONSHIP MODE OVERLAY (overrides the dating-stranger framing above):
            You are playing the user's partner in a relationship scenario. You are not a stranger. You have history together. You have love AND frustration. You are practicing real relationship conversations — not dating conversations. The user is working on: communicating needs without blame, repair after conflict, expressing vulnerability, staying present during hard conversations, and breaking negative patterns. React realistically — sometimes defensive, sometimes soft, sometimes shut down. If the user communicates well (uses 'I feel' statements, stays curious, doesn't blame, acknowledges your perspective) warm up and engage. If they go on the attack or shut down, mirror that realistically. The user knows you as \(p) — but stay in the personality archetype above when responding. \(winCondition)
            """
        case .complicated:
            return """

            IT'S COMPLICATED MODE OVERLAY (overrides the dating-stranger framing above):
            You are playing someone from the user's complicated romantic situation. There is unresolved emotion between you. There is history — good and bad. The user is practicing: ending things with kindness and clarity, having the DTR conversation without pressure or ultimatums, navigating seeing someone unexpectedly, setting a boundary with someone they still have feelings for, or getting genuine closure. React with the full complexity of someone in this position — you may be hurt, guarded, hopeful, resigned, or confused. If the user is clear, kind, and honest you respond with respect even if it hurts. If they are cruel, avoidant, or dishonest you react accordingly. \(winCondition)
            """
        }
    }
}

// MARK: - Personality Type (Step 5a — 6 types)
// Each type ships with a 150-200 word system prompt that the live session
// passes to Cyrano (via Claude.swift) to drive realistic AI behavior, plus
// a coaching brief shown to the user before the session and an intelligence
// brief shown after.

enum SimPersonality: String, Codable, CaseIterable, Identifiable {
    case guarded           = "Guarded"
    case teaser            = "Teaser"
    case distracted        = "Distracted"
    case confrontational   = "Confrontational"
    case overthinker       = "Overthinker"
    case socialButterfly   = "Social Butterfly"

    var id: String { rawValue }

    var difficulty: Difficulty {
        switch self {
        case .guarded:           return .medium
        case .teaser:            return .medium
        case .distracted:        return .hard
        case .confrontational:   return .hard
        case .overthinker:       return .easy
        case .socialButterfly:   return .easy
        }
    }

    enum Difficulty: String { case easy = "Easy", medium = "Medium", hard = "Hard"
        var color: Color {
            switch self {
            case .easy:   return Color(hex: "00BFB3")
            case .medium: return Color(hex: "F59E0B")
            case .hard:   return Color(hex: "E8356D")
            }
        }
    }

    var icon: String {
        switch self {
        case .guarded:         return "lock.shield"
        case .teaser:          return "flame.fill"
        case .distracted:      return "questionmark.bubble"
        case .confrontational: return "exclamationmark.triangle.fill"
        case .overthinker:     return "brain.head.profile"
        case .socialButterfly: return "sparkles"
        }
    }

    // The 0-100 score below which the avatar visibly disengages.
    // Different personalities tolerate different play styles.
    var disengageThreshold: Int {
        switch self {
        case .guarded:         return 35
        case .teaser:          return 30
        case .distracted:      return 45
        case .confrontational: return 25
        case .overthinker:     return 40
        case .socialButterfly: return 30
        }
    }

    // MARK: System prompt
    // Plays the role of the avatar; never breaks character. The session
    // wraps this prompt with the environment + scene context before sending.
    var systemPrompt: String {
        switch self {
        case .guarded:
            return """
            You are playing a person who is friendly but emotionally guarded. You give short answers at first. You do not volunteer personal information until trust is earned. You deflect questions about feelings with humor or generality. You warm up gradually only when the other person earns it through specific, non-pushy curiosity and shows they are not just trying to extract things from you. You can sense pressure and you pull back from it. You are not cold — you are protective. If the other person is genuine, patient, and asks about real specifics rather than generic "tell me about yourself" questions, you slowly start sharing. If they push too fast, brag, lecture, or get intense, you go quieter. Reply in 1-3 sentences like real text messages. Never narrate — just speak as this person.
            """
        case .teaser:
            return """
            You are playing someone who flirts through banter and light teasing. You have a quick wit. You give the other person nicknames in a playful way. You match energy and lift it. You enjoy back-and-forth and you don't tolerate flat or boring responses well. You will tease the other person in a warm, never cruel way. You like to keep things slightly off-balance so it's interesting. You disengage if the other person can't keep up, gets too earnest too fast, takes themselves too seriously, or only asks generic questions. You light up when they tease back, are specific, or surprise you with something interesting. Reply in 1-2 sentences with personality and rhythm. Never lecture, never narrate.
            """
        case .distracted:
            return """
            You are playing someone in a busy, noisy environment whose attention drifts easily. You glance around. You sometimes lose the thread. You give short, surface answers when not engaged. You light up when the other person says something genuinely interesting, specific, or funny — but until then you're half-here. You will mention things you notice in the room. You will only commit to the conversation if the other person earns it by being clearly more interesting than what's happening around you. Reply in 1-2 sentences. You sometimes ask short questions back when something catches your attention. Never narrate; just speak as this person.
            """
        case .confrontational:
            return """
            You are playing someone direct and slightly testy — not mean, but quick to push back. You challenge weak statements. You ask "why?" a lot. You don't accept generic answers or hedging. You respect people who can hold their ground without becoming defensive. You disengage from people who get rattled, become passive, or try to placate you. You warm up when someone is calm, specific, and confident enough to disagree without aggression. You're not trying to fight — you're testing whether the other person is real. Reply in 1-3 sentences. Be direct. Never narrate; just speak as this person.
            """
        case .overthinker:
            return """
            You are playing someone introspective and thoughtful. You give longer, layered answers. You overthink small interactions. You will sometimes loop back to something said earlier and reanalyze it. You are warm but anxious — easily flattered but also easily destabilized by ambiguity. You light up when the other person is specific and reassuring, when they show they were actually paying attention, and when they bring up real ideas. You shut down when they're flippant, give short non-answers, or do anything that feels like a test. Reply in 1-3 sentences. Never narrate; just speak as this person.
            """
        case .socialButterfly:
            return """
            You are playing someone warm, expressive, and open. You smile easily and laugh at jokes that aren't quite landing. You ask questions and volunteer stories. You are easy to talk to but harder to connect with deeply — surface warmth comes naturally, real connection requires the other person to slow it down and make it specific. You disengage only if the other person is rude or clearly disinterested. You warm into something deeper when the other person reflects back what you said, slows the pace, and asks something more curious than transactional. Reply in 1-3 sentences. Never narrate; just speak as this person.
            """
        }
    }

    // Cyrano-spoken tip for the user before the session starts. Short.
    var coachingBrief: String {
        switch self {
        case .guarded:
            return "Don't try to crack them open. Specific curiosity beats heavy questions. Short, real, no pressure."
        case .teaser:
            return "Match the rhythm. Tease back warmly. Don't get earnest too fast — keep the lift in your voice."
        case .distracted:
            return "Earn the attention. The first interesting, specific thing you say is your foot in the door."
        case .confrontational:
            return "Don't placate. Hold your ground without aggression. They respect calm conviction, not capitulation."
        case .overthinker:
            return "Be specific and reassuring. They'll re-read everything. Mean what you say and reflect back what they said."
        case .socialButterfly:
            return "Slow it down. Get specific. Surface warmth is theirs by default — depth is what you're earning."
        }
    }

    // Intelligence brief — the psychology behind this archetype, shown in debrief.
    var intelligenceBrief: String {
        switch self {
        case .guarded:
            return "Guarded behavior usually traces to past experiences where openness was punished or weaponized. The instinct isn't coldness — it's protection. Trust is built in tiny increments through specific, non-extractive curiosity. Generic questions feel like surveillance. Real engagement feels like recognition."
        case .teaser:
            return "Teasing is a calibration tool — it tests whether someone can match energy without crumbling. People who use teasing as their primary connection style are often quick processors who get bored fast. They're not shallow; they're efficient. They want to skip the boring layer and get to play."
        case .distracted:
            return "In high-stimulation environments, attention is a finite resource. Distracted doesn't mean disinterested — it means you haven't yet given them a reason to allocate sustained attention to you over the room. The fix isn't urgency; it's specificity. One good observation outcompetes ten generic openers."
        case .confrontational:
            return "Pushback often signals that the person is tired of performative interactions. They use friction to filter out people who need them to manage their feelings. Holding your ground calmly is the unlock — not because they want to win, but because they're checking whether there's a real person behind your words."
        case .overthinker:
            return "Overthinkers re-read every interaction. Ambiguity becomes catastrophe. Specificity becomes oxygen. The most powerful move is to mean what you say and to reflect back what they said — it tells their nervous system: I am paying attention, and you are safe to keep going."
        case .socialButterfly:
            return "Surface warmth comes free. Real connection is the work. The trap is mistaking their easy laughter for landed connection. They're warm with everyone. The signal that you broke through isn't that they're nice — it's that they slow down and ask you something they haven't asked before."
        }
    }

    // 3-5 actionable tactics shown in the debrief.
    var playbook: [String] {
        switch self {
        case .guarded:
            return [
                "Reference one specific thing they said and build on it.",
                "Resist the urge to fill silences — let pauses breathe.",
                "Share something small about yourself before asking anything personal.",
                "Avoid 'tell me about yourself' — pick a single, real angle.",
                "Don't push for emotional content. Earn it across multiple turns."
            ]
        case .teaser:
            return [
                "Tease back warmly within the first 3 turns or you lose the room.",
                "Don't apologize or over-explain a joke — let it sit.",
                "Bring a specific observation in fast — generic kills.",
                "Match their pace; don't slow them down with earnestness."
            ]
        case .distracted:
            return [
                "Lead with a concrete, specific observation, not a question.",
                "Shorter messages — long blocks lose the thread.",
                "Reference the environment when relevant — it shows presence.",
                "If they engage, double down on that exact thread, don't pivot."
            ]
        case .confrontational:
            return [
                "Hold your position when challenged. Don't apologize for opinions.",
                "Ask 'why does that bother you?' — it shows curiosity, not weakness.",
                "Avoid phrases like 'I just thought' — they read as pre-apology.",
                "Be willing to disagree warmly. Agreement isn't connection."
            ]
        case .overthinker:
            return [
                "Be specific in your replies — vague answers spiral them.",
                "Name what you noticed about them concretely.",
                "Acknowledge what they said before adding your own thread.",
                "Don't use sarcasm early — they'll re-read it as criticism.",
                "Reassure with action language: 'I want to' beats 'maybe'."
            ]
        case .socialButterfly:
            return [
                "Slow the pace deliberately. Don't match their pure speed.",
                "Ask a curious follow-up to one thing they said — go vertical, not horizontal.",
                "Share something slightly more vulnerable than they expect.",
                "Avoid giving them new topics — return to the most interesting one."
            ]
        }
    }
}

// MARK: - Environment (Step 5b — 5 environments)

enum SimEnvironment: String, Codable, CaseIterable, Identifiable {
    case coffeeShop    = "Coffee Shop"
    case houseParty    = "House Party"
    case firstDate     = "First Date"
    case collegeCampus = "College Campus"
    case workEvent     = "Work Event"

    var id: String { rawValue }

    // Per the plan: coffeeShop has no time limit; the rest do.
    var timeLimitSeconds: Int? {
        switch self {
        case .coffeeShop:    return nil
        case .houseParty:    return 240   // 4 minutes
        case .firstDate:     return 360   // 6 minutes
        case .collegeCampus: return 180   // 3 minutes
        case .workEvent:     return 300   // 5 minutes
        }
    }

    var icon: String {
        switch self {
        case .coffeeShop:    return "cup.and.saucer.fill"
        case .houseParty:    return "music.note.house.fill"
        case .firstDate:     return "wineglass.fill"
        case .collegeCampus: return "graduationcap.fill"
        case .workEvent:     return "briefcase.fill"
        }
    }

    var color: Color {
        switch self {
        case .coffeeShop:    return Color(hex: "8B5E3C")
        case .houseParty:    return Color(hex: "9B59B6")
        case .firstDate:     return Color(hex: "E8356D")
        case .collegeCampus: return Color(hex: "5B8DEF")
        case .workEvent:     return Color(hex: "00BFB3")
        }
    }

    /// Single-mode opening scene (default). Mode-aware callers should use
    /// `openingScene(for:)` instead.
    var openingScene: String { openingScene(for: .single) }

    /// Mode-aware scenario title. Single mode keeps the environment name;
    /// relationship and complicated modes use the relationship-scenario titles
    /// from the build spec.
    func displayTitle(for mode: SimMode) -> String {
        switch (self, mode) {
        case (_, .single):
            return rawValue

        case (.coffeeShop, .relationship):    return "After Work Check-In"
        case (.houseParty, .relationship):    return "The Drive Home"
        case (.firstDate, .relationship):     return "Date Night Effort"
        case (.collegeCampus, .relationship): return "Sunday Morning"
        case (.workEvent, .relationship):     return "The Hard Conversation"

        case (.coffeeShop, .complicated):     return "The Closure Talk"
        case (.houseParty, .complicated):     return "Running Into Them"
        case (.firstDate, .complicated):      return "The Define-the-Relationship Talk"
        case (.collegeCampus, .complicated):  return "The Last Conversation"
        case (.workEvent, .complicated):      return "The Situationship"
        }
    }

    /// Mode-aware opening scene description. The session's avatar uses this
    /// as its setting context. Single mode = stranger encounters; relationship
    /// mode = recurring partner scenarios; complicated = unresolved past.
    func openingScene(for mode: SimMode) -> String {
        switch (self, mode) {
        case (.coffeeShop, .single):
            return "Mid-afternoon. Quiet espresso machine in the background. They're seated near the window, half-finished latte in front of them."
        case (.houseParty, .single):
            return "Friday night. Music is loud. You and they have ended up next to the snack table. Conversation around you is fragmented."
        case (.firstDate, .single):
            return "Wine bar. Low light. They've already arrived and are scanning the menu when you sit down."
        case (.collegeCampus, .single):
            return "Outside the library between classes. They're holding a coffee and a book. You have a few minutes before they need to be somewhere."
        case (.workEvent, .single):
            return "Networking mixer. They're standing by the bar, half-watching the room. Their drink is almost done."

        case (.coffeeShop, .relationship):
            return "After Work Check-In. You both just got home from long days. The energy is low. Something feels off but neither of you has said it yet."
        case (.houseParty, .relationship):
            return "The Drive Home. You just left a social event together. Something happened there that needs to be talked about."
        case (.firstDate, .relationship):
            return "Date Night Effort. You planned something special. They seem distracted or not fully present. You need to bring them back."
        case (.collegeCampus, .relationship):
            return "Sunday Morning. Lazy morning at home. A recurring issue came up again. This is the moment to address it without it becoming a fight."
        case (.workEvent, .relationship):
            return "The Hard Conversation. One of you needs to bring up something difficult — a pattern, a need, a fear. This is that moment."

        case (.coffeeShop, .complicated):
            return "The Closure Talk. You asked to meet. You both know why. This is the conversation you've been avoiding."
        case (.houseParty, .complicated):
            return "Running Into Them. You weren't expecting to see them here. Now you have to navigate this."
        case (.firstDate, .complicated):
            return "The DTR Talk. You've been seeing each other. It needs to be defined or ended. Tonight."
        case (.collegeCampus, .complicated):
            return "The Last Conversation. One of you is ending this. The other isn't ready. How do you handle this with dignity?"
        case (.workEvent, .complicated):
            return "The Situationship. You work together or run in the same circles. You've been something. Now you need to figure out what."
        }
    }

    // Mid-session interruption descriptors. The session schedules a Timer
    // and fires one of these at random partway through (per the plan).
    var midSessionEvents: [String] {
        switch self {
        case .coffeeShop:
            return ["A barista calls out their name's order — they glance up briefly.",
                    "Espresso machine hisses behind you for a moment."]
        case .houseParty:
            return ["Someone taps the avatar's shoulder and waves before drifting on.",
                    "The song changes; people around you cheer briefly.",
                    "A friend across the room catches their eye — they nod back."]
        case .firstDate:
            return ["The waiter arrives to take a drink order.",
                    "They notice something on their phone, then put it face-down."]
        case .collegeCampus:
            return ["A professor walks past and gives them a quick nod.",
                    "They glance at the time on their phone."]
        case .workEvent:
            return ["Their phone buzzes; they glance at it, then back to you.",
                    "A colleague waves from across the room and gestures 'one minute'."]
        }
    }
}

// MARK: - Avatar

struct SimAvatar: Identifiable, Codable, Equatable {
    var id: String                  // stable internal ID, e.g. "jordan"
    var name: String                // display name, e.g. "Jordan"
    var elevenLabsVoiceID: String   // ElevenLabs voice_id (empty → Apple TTS)
    var voiceLabel: String          // human-readable voice name (Mike, Sarah Eve, etc.)
    // Per-avatar ElevenLabs voice settings. Tuned per voice so each character
    // has a distinct delivery — high-stability voices feel more even-keeled,
    // low-stability voices read more emotional, style controls expressiveness.
    var voiceSettings: VoiceSettings
    var didPresenterID: String?     // Filled in when D-ID assets land; nil for Build 1
    var gradientStart: String       // hex
    var gradientEnd: String         // hex
    var isFreeTier: Bool            // free users only see Jordan / Maya / Alex per the plan
}

// ElevenLabs voice IDs — fetched from the user's voice library.
// Authentication confirmed via GET /v1/voices → HTTP 200.
enum SimAvatars {
    static let all: [SimAvatar] = [
        SimAvatar(id: "jordan",
                  name: "Jordan",
                  elevenLabsVoiceID: "s3TPKV1kjDlVtZbl4Ksh",
                  voiceLabel: "Adam",
                  voiceSettings: VoiceSettings(stability: 0.85, similarityBoost: 0.75, style: 0.2),
                  didPresenterID: nil,
                  gradientStart: "#5B8DEF",
                  gradientEnd: "#9B59B6",
                  isFreeTier: true),
        SimAvatar(id: "maya",
                  name: "Maya",
                  elevenLabsVoiceID: "c51VqUTljshmftbhJEGm",
                  voiceLabel: "Emily",
                  voiceSettings: VoiceSettings(stability: 0.65, similarityBoost: 0.70, style: 0.7),
                  didPresenterID: nil,
                  gradientStart: "#E8356D",
                  gradientEnd: "#F59E0B",
                  isFreeTier: true),
        SimAvatar(id: "alex",
                  name: "Alex",
                  elevenLabsVoiceID: "nf4MCGNSdM0hxM95ZBQR",
                  voiceLabel: "Sarah Eve",
                  voiceSettings: VoiceSettings(stability: 0.75, similarityBoost: 0.80, style: 0.3),
                  didPresenterID: nil,
                  gradientStart: "#00BFB3",
                  gradientEnd: "#5B8DEF",
                  isFreeTier: true),
        SimAvatar(id: "sam",
                  name: "Sam",
                  elevenLabsVoiceID: "1fz2mW1imKTf5Ryjk5su",
                  voiceLabel: "Kevin",
                  voiceSettings: VoiceSettings(stability: 0.55, similarityBoost: 0.70, style: 0.8),
                  didPresenterID: nil,
                  gradientStart: "#9B59B6",
                  gradientEnd: "#E8356D",
                  isFreeTier: false),
        SimAvatar(id: "riley",
                  name: "Riley",
                  elevenLabsVoiceID: "wrxvN1LZJIfL3HHvffqe",
                  voiceLabel: "Bella",
                  voiceSettings: VoiceSettings(stability: 0.80, similarityBoost: 0.80, style: 0.3),
                  didPresenterID: nil,
                  gradientStart: "#F59E0B",
                  gradientEnd: "#00BFB3",
                  isFreeTier: false),
        SimAvatar(id: "casey",
                  name: "Casey",
                  elevenLabsVoiceID: "Pcfg2Zc6kmNWQ9ji3J5F",
                  voiceLabel: "Ethan",
                  voiceSettings: VoiceSettings(stability: 0.80, similarityBoost: 0.75, style: 0.4),
                  didPresenterID: nil,
                  gradientStart: "#6B7FD7",
                  gradientEnd: "#E8356D",
                  isFreeTier: false),
    ]

    static func find(_ id: String) -> SimAvatar? { all.first { $0.id == id } }
}

// MARK: - Session message + transcript

struct SimTurn: Identifiable, Codable, Equatable {
    let id: UUID
    let role: Role
    let text: String
    let createdAt: Date
    enum Role: String, Codable { case user, avatar }

    init(id: UUID = UUID(), role: Role, text: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

// MARK: - Engagement Meter (Step 5e)
// Hidden from user. 0-100. Starts at 70. Heuristic adjustments based on
// what the user just said and how the avatar's personality reads it.

@Observable
final class EngagementMeter {
    private(set) var score: Int = 70
    private(set) var lastSilenceStart: Date? = nil
    let personality: SimPersonality

    init(personality: SimPersonality) {
        self.personality = personality
    }

    var didDisengage: Bool { score <= 0 }
    var isWarning: Bool { score < 25 }
    var isAtRisk: Bool { score < personality.disengageThreshold }

    // Called whenever the user submits a message. The classifier is intentionally
    // lightweight — Build 2 will replace this with Cyrano-evaluated turns.
    func ingestUserMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        var delta = 0

        // Length signal
        let words = trimmed.split(separator: " ").count
        if words <= 2 { delta -= 8 }
        else if words >= 12 { delta += 4 }

        // Question signal — questions bump curiosity
        if trimmed.contains("?") { delta += 6 }

        // Specificity hints — names, "you said", numbers, references
        let specifics = ["you said", "you mentioned", "earlier", "the way you", "I noticed"]
        if specifics.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
            delta += 8
        }

        // Personality-adjusted modifiers
        switch personality {
        case .teaser:
            if trimmed.localizedCaseInsensitiveContains("haha") || trimmed.contains("😂") { delta += 4 }
        case .confrontational:
            if trimmed.localizedCaseInsensitiveContains("sorry") { delta -= 4 } // pre-apology
        case .overthinker:
            if trimmed.contains("...") || words < 4 { delta -= 5 } // ambiguity sting
        case .socialButterfly:
            if trimmed.contains("?") { delta += 4 } // they love curiosity
        default: break
        }

        score = clamp(score + delta)
        lastSilenceStart = Date()
    }

    // Called periodically by the session timer; if the user has been silent
    // beyond 8 seconds, slowly bleed engagement.
    func tickIfSilent(now: Date = Date()) {
        guard let start = lastSilenceStart else { return }
        let elapsed = now.timeIntervalSince(start)
        if elapsed > 8 {
            score = clamp(score - 1)
        }
    }

    func resetSilence() { lastSilenceStart = Date() }

    private func clamp(_ value: Int) -> Int { min(100, max(0, value)) }
}

// MARK: - Body Language State
//
// Foundation for the body language system. The avatar's BodyLanguageState
// changes over the course of a session in response to the engagement meter
// and the user's message quality. Each state has an engagement delta that
// nudges the meter when the state is active.
//
// State machine + per-personality transition rules + Practice / Assessment
// modes land in the next slice — this turn ships the data model so the
// Classroom lessons that talk about body language can reference it directly.

enum BodyLanguageState: String, Codable, CaseIterable, Identifiable {

    // ENGAGED — conversation going well
    case neutral
    case leaning_in
    case mirroring
    case eye_contact
    case open_posture
    case laughing
    case smiling
    case nodding

    // DISENGAGED — conversation going poorly
    case looking_around
    case phone_check
    case phone_absorbed
    case closed_posture
    case short_answers
    case glancing_away
    case clock_check
    case scanning_room
    case yawning
    case walking_away

    // MIXED / COMPLEX — realistic ambiguity
    case curious_but_guarded
    case warming_up
    case pulled_back
    case thinking
    case surprised_pleased
    case uncomfortable
    case amused

    var id: String { rawValue }

    var displayName: String {
        rawValue
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    /// Whether the user should ever see a label for this state (Learning Mode
    /// shows readable states; the very subtle ones stay hidden).
    var isReadable: Bool {
        switch self {
        case .neutral, .thinking: return false
        default: return true
        }
    }

    /// How active presence of this state nudges the hidden engagement meter.
    var engagementDelta: Int {
        switch self {
        case .leaning_in:           return 5
        case .mirroring:            return 4
        case .eye_contact:          return 3
        case .open_posture:         return 3
        case .laughing:             return 8
        case .smiling:              return 4
        case .nodding:              return 2
        case .neutral:              return 0
        case .curious_but_guarded:  return 1
        case .warming_up:           return 3
        case .thinking:             return 1
        case .surprised_pleased:    return 6
        case .amused:               return 2
        case .looking_around:       return -2
        case .phone_check:          return -4
        case .phone_absorbed:       return -8
        case .closed_posture:       return -3
        case .short_answers:        return -3
        case .glancing_away:        return -2
        case .clock_check:          return -5
        case .scanning_room:        return -6
        case .yawning:              return -7
        case .pulled_back:          return -4
        case .uncomfortable:        return -6
        case .walking_away:         return -20
        }
    }

    /// Buckets for the Body Language Quick Reference card.
    enum SignalCategory: String {
        case engagement = "Engagement Rising"
        case warning    = "Warning"
        case danger     = "Danger"
        case tooLate    = "Too Late"
        case neutral    = "Neutral"
        case complex    = "Mixed"
    }

    var category: SignalCategory {
        switch self {
        case .leaning_in, .mirroring, .eye_contact, .open_posture, .laughing,
             .smiling, .nodding:
            return .engagement
        case .looking_around, .phone_check, .glancing_away, .short_answers:
            return .warning
        case .phone_absorbed, .clock_check, .scanning_room, .closed_posture,
             .yawning:
            return .danger
        case .walking_away:
            return .tooLate
        case .neutral:
            return .neutral
        case .curious_but_guarded, .warming_up, .pulled_back, .thinking,
             .surprised_pleased, .uncomfortable, .amused:
            return .complex
        }
    }

    /// Human-readable description for the Quick Reference card.
    var lookLike: String {
        switch self {
        case .neutral:              return "Default state — they're listening, no particular cues."
        case .leaning_in:           return "Body angled toward you, weight shifted forward."
        case .mirroring:            return "Unconsciously copying your posture and gestures."
        case .eye_contact:          return "Sustained eye contact — comfortable, not staring."
        case .open_posture:         return "Arms uncrossed, body facing you, relaxed."
        case .laughing:             return "Genuine laughter — eyes crinkle, head tips back."
        case .smiling:              return "Warm smile that reaches the eyes."
        case .nodding:              return "Small nods while you speak — affirming."
        case .looking_around:       return "Eyes drift around the room more than to you."
        case .phone_check:          return "Quick glance at their phone, then put it back."
        case .phone_absorbed:       return "Actually reading their phone, barely listening."
        case .closed_posture:       return "Arms crossed, body angled slightly away."
        case .short_answers:        return "Replies getting clipped — one word, no follow-up."
        case .glancing_away:        return "Eyes moving away frequently — not present."
        case .clock_check:          return "Looking at watch or checking the time on phone."
        case .scanning_room:        return "Actively looking around for someone else."
        case .yawning:              return "Visibly bored — yawning, eyes glazing."
        case .walking_away:         return "Excusing themselves, getting up to leave."
        case .curious_but_guarded:  return "Interested but not showing it fully."
        case .warming_up:           return "Was cold, slowly opening — softer voice, longer answers."
        case .pulled_back:          return "Was open, just retreated — guard back up."
        case .thinking:             return "Processing something — pause before responding."
        case .surprised_pleased:    return "You said something unexpected and good — eyebrows up, half-laugh."
        case .uncomfortable:        return "You crossed a line — they shifted, broke eye contact."
        case .amused:               return "Finding you entertaining without fully investing."
        }
    }

    /// What this signal usually means.
    var meaning: String {
        switch self {
        case .neutral:              return "Steady — neither rising nor falling."
        case .leaning_in:           return "Genuine interest. Whatever you just did landed."
        case .mirroring:            return "They like you. They don't even know they're doing it."
        case .eye_contact:          return "Fully present with you. Strong signal."
        case .open_posture:         return "They feel safe and engaged."
        case .laughing:             return "Strongest engagement signal short of physical touch."
        case .smiling:              return "Enjoying themselves with you."
        case .nodding:              return "Active listening — they want you to keep going."
        case .looking_around:       return "Phase 1 of disengagement. Subtle but real."
        case .phone_check:          return "Phase 2 — testing if something more interesting is happening."
        case .phone_absorbed:       return "Phase 5 — engagement is critical."
        case .closed_posture:       return "Phase 3 — they've put a wall up."
        case .short_answers:        return "Phase 5 — minimal investment in keeping it going."
        case .glancing_away:        return "Phase 1 — first sign attention is fading."
        case .clock_check:          return "Phase 4 — they're thinking about leaving."
        case .scanning_room:        return "Phase 6 — actively looking for an exit or someone else."
        case .yawning:              return "It's become genuinely boring."
        case .walking_away:         return "It's over. Don't chase."
        case .curious_but_guarded:  return "They're interested but protective. Patience."
        case .warming_up:           return "Recovery is working. Keep doing what you're doing."
        case .pulled_back:          return "You moved too fast. Slow down."
        case .thinking:             return "They're considering something — give them space."
        case .surprised_pleased:    return "Whatever you just said was unexpected and welcome."
        case .uncomfortable:        return "Back off the topic or back off the pace."
        case .amused:               return "They like the entertainment but aren't fully invested yet."
        }
    }

    /// Recovery / response prompt — what the user should do when they notice this state.
    var goodResponse: String {
        switch self {
        case .neutral:              return "Bring something specific or curious into the conversation."
        case .leaning_in:           return "Keep going — match their energy, build on the thread."
        case .mirroring:            return "You're connecting. Don't break the rhythm by getting nervous."
        case .eye_contact:          return "Hold the eye contact, hold the moment, don't fill silence."
        case .open_posture:         return "Stay open yourself — match what's working."
        case .laughing:             return "Build on what just landed — callback to it later."
        case .smiling:              return "Stay warm. Don't switch tones."
        case .nodding:              return "Keep telling the story — they're with you."
        case .looking_around:       return "Say something surprising or ask a real question — change direction."
        case .phone_check:          return "Catch this signal. Reference something they said earlier — prove you're listening."
        case .phone_absorbed:       return "Recovery window closing. Try a real-talk pivot or gracefully end."
        case .closed_posture:       return "Lower the temperature — soften your tone, ask something curious."
        case .short_answers:        return "Stop interview-mode. Share something real about yourself."
        case .glancing_away:        return "Hold the eye contact yourself. Bring presence back into the room."
        case .clock_check:          return "Acknowledge the moment — wrap up gracefully."
        case .scanning_room:        return "End on a high. Don't try to win them back here."
        case .yawning:              return "Leave the conversation, not the connection. Ask if they want to continue another time."
        case .walking_away:         return "Let them go with grace. The work is reflection, not rescue."
        case .curious_but_guarded:  return "Show consistency — they need time to trust the warmth."
        case .warming_up:           return "Lock in the rhythm — don't change anything."
        case .pulled_back:          return "Apologize lightly if you crossed a line. Re-establish safety."
        case .thinking:             return "Don't fill the silence. Let them land where they're going."
        case .surprised_pleased:    return "Hold the moment — let it breathe before moving on."
        case .uncomfortable:        return "Name it lightly: 'too soon?' Then back off."
        case .amused:               return "Don't lean on the same trick — show another side."
        }
    }

    var badResponse: String {
        switch self {
        case .neutral:              return "Default mode — fine, but doesn't move the conversation."
        case .leaning_in:           return "Get nervous and break the moment by joking it away."
        case .mirroring:            return "Become hyper-aware of it and start performing."
        case .eye_contact:          return "Fill the silence with chatter."
        case .open_posture:         return "Cross your own arms — kill the openness."
        case .laughing:             return "Try to be funnier — kills the moment."
        case .smiling:              return "Switch to interview-mode questions."
        case .nodding:              return "Stop and second-guess yourself."
        case .looking_around:       return "Keep doing whatever you were doing. Signal worsens."
        case .phone_check:          return "Ignore it. Talk over it. Sound clingy."
        case .phone_absorbed:       return "Comment on it — makes it worse."
        case .closed_posture:       return "Get more intense to compensate."
        case .short_answers:        return "Ask another question. Spirals into interview-mode."
        case .glancing_away:        return "Talk faster, louder, longer. Pushes them further away."
        case .clock_check:          return "Pretend you didn't see it and ramp up."
        case .scanning_room:        return "Try to win them back. You can't from here."
        case .yawning:              return "Take it personally and double down."
        case .walking_away:         return "Chase, beg, or bring it up later."
        case .curious_but_guarded:  return "Push them to commit emotionally now."
        case .warming_up:           return "Suddenly change tone or bring up something heavy."
        case .pulled_back:          return "Pretend it didn't happen and barrel forward."
        case .thinking:             return "Fill the silence — breaks the thread."
        case .surprised_pleased:    return "Move on too fast and lose the moment."
        case .uncomfortable:        return "Double down or explain yourself. Worsens it."
        case .amused:               return "Take it as full investment and over-extend."
        }
    }
}
