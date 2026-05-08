import Foundation
import SwiftUI
import Security
import CoreLocation

// MARK: - App State

@Observable
class AppState {
    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "onboarded") }
    }
    var isInRelationship: Bool {
        didSet { UserDefaults.standard.set(isInRelationship, forKey: "inRelationship") }
    }
    var appMode: AppMode

    init() {
        let onboarded = UserDefaults.standard.bool(forKey: "onboarded")
        let inRel = UserDefaults.standard.bool(forKey: "inRelationship")
        self.hasCompletedOnboarding = onboarded
        self.isInRelationship = inRel
        self.appMode = inRel ? .relationship : .single
    }

    func switchToKeepMode() { isInRelationship = true; appMode = .relationship }
    func switchToHuntMode() { isInRelationship = false; appMode = .single }
}

enum AppMode: Equatable {
    case single, relationship
    var accentColor: Color {
        self == .single ? .rwAccent : .rwGold
    }
}

// MARK: - AI Settings

@Observable
class AISettings {
    static let shared = AISettings()
    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "aiEnabled") }
    }
    init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "aiEnabled") as? Bool ?? true
    }
}


// MARK: - App Language

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case english    = "English"
    case spanish    = "Spanish"
    case french     = "French"
    case portuguese = "Portuguese"
    case german     = "German"
    case italian    = "Italian"
    case japanese   = "Japanese"
    case korean     = "Korean"
    case mandarin   = "Mandarin"
    case arabic     = "Arabic"
    case hindi      = "Hindi"

    var id: String { rawValue }

    var flag: String {
        switch self {
        case .english:    return "🇺🇸"
        case .spanish:    return "🇪🇸"
        case .french:     return "🇫🇷"
        case .portuguese: return "🇧🇷"
        case .german:     return "🇩🇪"
        case .italian:    return "🇮🇹"
        case .japanese:   return "🇯🇵"
        case .korean:     return "🇰🇷"
        case .mandarin:   return "🇨🇳"
        case .arabic:     return "🇸🇦"
        case .hindi:      return "🇮🇳"
        }
    }

    var promptInstruction: String {
        if self == .english { return "" }
        return "IMPORTANT: Respond entirely in \(rawValue). All coaching, suggestions, and feedback must be in \(rawValue)."
    }
}

// MARK: - Love Language

enum LoveLanguage: String, Codable, CaseIterable, Identifiable {
    case words = "Words of Affirmation"
    case acts  = "Acts of Service"
    case gifts = "Receiving Gifts"
    case time  = "Quality Time"
    case touch = "Physical Touch"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .words: return "text.bubble.fill"
        case .acts:  return "hands.sparkles.fill"
        case .gifts: return "gift.fill"
        case .time:  return "clock.fill"
        case .touch: return "hand.raised.fill"
        }
    }

    var color: Color {
        switch self {
        case .words: return Color(hex: "E8356D")
        case .acts:  return Color(hex: "5B8DEF")
        case .gifts: return Color(hex: "F59E0B")
        case .time:  return Color(hex: "00BFB3")
        case .touch: return Color(hex: "9B59B6")
        }
    }

    var shortDescription: String {
        switch self {
        case .words: return "You feel loved through compliments and verbal appreciation."
        case .acts:  return "You feel loved when people do things for you."
        case .gifts: return "Thoughtful gestures and presents mean a lot to you."
        case .time:  return "Undivided attention and presence is everything."
        case .touch: return "Physical closeness and affection speaks to you."
        }
    }

    var datingImplication: String {
        switch self {
        case .words: return "Pay attention to how they talk to you — compliments and encouragement matter."
        case .acts:  return "Watch for effort: do they show up? Do they help? Actions speak louder."
        case .gifts: return "Thoughtfulness in small gestures signals real investment."
        case .time:  return "Undivided attention early on tells you a lot about their priorities."
        case .touch: return "Comfort with appropriate physical closeness is an important signal."
        }
    }
}

// MARK: - User

struct RWUser: Codable, Identifiable {
    var id = UUID().uuidString
    var name = ""
    var gender: Gender = .preferNotToSay
    var attachmentStyle: AttachmentStyle = .secure
    var datingGoal: DatingGoal = .relationship
    var loveLanguages: [LoveLanguage] = []
    var isFirstRelationship: Bool? = nil  // nil = not answered yet
    var preferredLanguage: AppLanguage = .english
    var coinBalance = 10
    var isPro = false
    var createdAt = Date()

    // Smart Onboarding (Build 1 Step 2)
    var relationshipStatus: RelationshipStatus = .single
    var partnerName: String? = nil
    var relationshipDuration: RelationshipDuration? = nil
    var relationshipGoals: [RelationshipGoal] = []
    // Generated when the user opts to invite their partner; the partner enters this
    // 6-digit code in their own onboarding to pair the two accounts. Pairing/sync
    // logic comes in a later build — for now we just persist the code.
    var partnerInviteCode: String? = nil

    // Breakup Recovery Mode (Build 1 Step 10 stub) — when true, the home surface
    // hides dating features and routes to BreakupRecoveryView. Full mode in Build 2.
    var isInBreakupRecovery: Bool = false

    enum Gender: String, Codable, CaseIterable {
        case male = "Male"
        case female = "Female"
        case preferNotToSay = "Prefer Not to Say"

        var coachingContext: String {
            switch self {
            case .male:
                return "The user identifies as male. Focus on helping them express genuine interest clearly, stand out with specificity, and build real connection. Safety and respect for the other person are always central."
            case .female:
                return "The user identifies as female. Trust their instincts. Safety is real and always a valid consideration. Help them filter effectively and engage on their own terms without pressure."
            case .preferNotToSay:
                return "Use inclusive, neutral coaching. Focus on authentic communication, reading behavioral signals, and building genuine connection. Make no gender assumptions about the user or the person they are talking to."
            }
        }

        var cyranoContext: String {
            switch self {
            case .male:
                return "Help craft a reply that is genuine, specific, and interesting — not generic or try-hard. Stand out by engaging with something real."
            case .female:
                return "Help craft a reply that feels true to her voice — warm where she wants to be warm, boundaried where she needs to be. Never pressure her to respond in a way that doesn't feel right."
            case .preferNotToSay:
                return "Help craft an authentic response that reflects the user's genuine personality and the energy of the conversation."
            }
        }

        var debriefContext: String {
            switch self {
            case .male:
                return "Focus on genuine connection signals from both sides. Did both people seem at ease? Was there real interest? What does the next move look like?"
            case .female:
                return "Trust her read of the situation. Did she feel safe and respected? Were there any moments that felt off? Her gut feelings are valid data worth exploring."
            case .preferNotToSay:
                return "Focus on how both people showed up, whether the connection felt genuine, and what the signals — positive or negative — actually mean."
            }
        }
    }

    // Brennan, Clark & Shaver (1998) ECR — four canonical styles.
    // Raw values are kept short ("Anxious", "Avoidant", "Disorganized") for clean UI
    // display and so that previously persisted users decode without migration.
    enum AttachmentStyle: String, Codable, CaseIterable {
        case secure = "Secure"
        case anxiousPreoccupied = "Anxious"
        case dismissiveAvoidant = "Avoidant"
        case fearfulAvoidant = "Disorganized"

        var description: String {
            switch self {
            case .secure: return "Comfortable with intimacy and independence."
            case .anxiousPreoccupied: return "Craves closeness but worries about partner's feelings."
            case .dismissiveAvoidant: return "Values independence. May pull back when things get close."
            case .fearfulAvoidant: return "Conflicting desires for closeness and distance."
            }
        }

        var color: Color {
            switch self {
            case .secure: return .rwSuccess
            case .anxiousPreoccupied: return .rwAccent
            case .dismissiveAvoidant: return Color(hex: "6B7FD7")
            case .fearfulAvoidant: return .rwGold
            }
        }

        var icon: String {
            switch self {
            case .secure: return "heart.fill"
            case .anxiousPreoccupied: return "waveform.path.ecg"
            case .dismissiveAvoidant: return "arrow.left.and.right.square"
            case .fearfulAvoidant: return "shuffle"
            }
        }
    }

    enum DatingGoal: String, Codable, CaseIterable {
        case relationship = "Serious Relationship"
        case casual = "Casual Dating"
        case unsure = "Not Sure Yet"

        var icon: String {
            switch self {
            case .relationship: return "heart.fill"
            case .casual: return "flame.fill"
            case .unsure: return "questionmark.circle.fill"
            }
        }
    }
}

// MARK: - Relationship Status (Smart Onboarding)

enum RelationshipStatus: String, Codable, CaseIterable, Identifiable {
    case single        = "single"
    case relationship  = "relationship"
    case complicated   = "complicated"

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .single:       return "I'm single"
        case .relationship: return "I'm in a relationship"
        case .complicated:  return "It's complicated"
        }
    }

    var subLabel: String {
        switch self {
        case .single:       return "Dating, looking, or just figuring it out"
        case .relationship: return "Actively building something together"
        case .complicated:  return "Healing, untangling, or somewhere in between"
        }
    }

    var icon: String {
        switch self {
        case .single:       return "person.fill"
        case .relationship: return "heart.fill"
        case .complicated:  return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .single:       return .rwAccent
        case .relationship: return .rwGold
        case .complicated:  return Color(hex: "6B7FD7")
        }
    }
}

// MARK: - Relationship Duration

enum RelationshipDuration: String, Codable, CaseIterable, Identifiable {
    case lessThanSixMonths = "Less than 6 months"
    case sixToTwelveMonths = "6-12 months"
    case oneToTwoYears     = "1-2 years"
    case threeToFiveYears  = "3-5 years"
    case fivePlusYears     = "5+ years"

    var id: String { rawValue }
}

// MARK: - Relationship Goal (multi-select, Smart Onboarding)

enum RelationshipGoal: String, Codable, CaseIterable, Identifiable {
    case communication = "Communication"
    case intimacy      = "Intimacy"
    case fun           = "Fun"
    case stability     = "Stability"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .communication: return "bubble.left.and.bubble.right.fill"
        case .intimacy:      return "heart.fill"
        case .fun:           return "sparkles"
        case .stability:     return "shield.lefthalf.filled"
        }
    }

    var subtitle: String {
        switch self {
        case .communication: return "Talk through hard things without them turning into fights"
        case .intimacy:      return "Deepen emotional and physical closeness"
        case .fun:           return "Bring back lightness, play, novelty"
        case .stability:     return "Build trust, rituals, and reliability"
        }
    }
}

// MARK: - Auth Service

@Observable
class AuthService {
    static let shared = AuthService()
    var currentUser: RWUser?
    private let userKey = "rw_user_profile"

    init() { load() }

    func save(_ user: RWUser) {
        currentUser = user
        if let data = try? JSONEncoder().encode(user) {
            Keychain.setData(data, key: userKey)
            UserDefaults.standard.removeObject(forKey: "user") // Remove legacy plaintext copy
        }
    }

    func update(_ block: (inout RWUser) -> Void) {
        guard var u = currentUser else { return }
        block(&u)
        save(u)
    }

    private func load() {
        // Primary: read from Keychain (encrypted, this-device-only)
        if let data = Keychain.getData(userKey),
           let user = try? JSONDecoder().decode(RWUser.self, from: data) {
            currentUser = user
            return
        }
        // Migration: move existing UserDefaults profile into Keychain on first upgrade
        if let data = UserDefaults.standard.data(forKey: "user"),
           let user = try? JSONDecoder().decode(RWUser.self, from: data) {
            currentUser = user
            save(user) // Writes to Keychain and removes the UserDefaults copy
        }
    }
}

// MARK: - Person

struct Person: Codable, Identifiable {
    var id = UUID().uuidString

    // MARK: - Basic Info
    var name = ""
    var age: Int? = nil
    var occupation = ""
    var location = ""
    // Geocoded coordinates for `location` — populated when the user picks a
    // suggestion from MKLocalSearchCompleter in EditContactView. Used by the
    // Date Planner "near this contact" and midpoint features.
    var contactLatitude: Double? = nil
    var contactLongitude: Double? = nil
    var hometown = ""
    var height = ""
    var school = ""
    var source: Source = .hinge
    var status: Status = .justMatched
    var rating = 0
    var isFavorite = false
    var isArchived = false

    // MARK: - Contact
    var phone = ""
    var email = ""
    var instagram = ""
    var snapchat = ""
    var twitter = ""

    // CNContact.identifier of the iOS contact this Person was imported from.
    // Stable across edits in the iOS Contacts app, so a Sync action can re-fetch
    // the latest name/photo/phone/email without losing the link.
    var iosContactIdentifier: String? = nil

    // MARK: - Dates & Timeline
    var firstContactDate = Date()
    var lastSpoke: Date? = nil
    var createdAt = Date()
    var dateHistory: [DateEntry] = []
    var nextDatePlanned: Date? = nil
    var nextDateLocation = ""
    var totalDates: Int { dateHistory.count }

    // MARK: - Personal Details
    var interests: [String] = []
    var dealBreakers: [String] = []
    var greenFlags: [String] = []
    var redFlags: [String] = []
    var thingsToAsk: [String] = []
    var thingsToAvoid: [String] = []
    var keyFacts: [String] = []

    // MARK: - Notes
    var notes = ""
    var privateNotes = ""

    // MARK: - Outcome
    var outcome: Outcome = .active
    var outcomeDate: Date? = nil
    var outcomeNotes = ""

    // MARK: - Computed
    var initial: String { String(name.prefix(1)).uppercased() }
    var daysSinceLastSpoke: Int? {
        guard let last = lastSpoke else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day
    }
    var isGoingCold: Bool {
        guard let days = daysSinceLastSpoke else { return false }
        return days >= 4 && status.isActive
    }
    var contactCoordinate: CLLocationCoordinate2D? {
        guard let lat = contactLatitude, let lng = contactLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    enum Outcome: String, Codable, CaseIterable {
        case active      = "Active"
        case stillDating = "Still Dating"
        case serious     = "Got Serious"
        case faded       = "Faded Out"
        case ended       = "Ended"
        case friendzoned = "Friends"

        var icon: String {
            switch self {
            case .active:      return "ellipsis.circle.fill"
            case .stillDating: return "heart.fill"
            case .serious:     return "heart.circle.fill"
            case .faded:       return "moon.fill"
            case .ended:       return "xmark.circle.fill"
            case .friendzoned: return "person.2.fill"
            }
        }
        var color: Color {
            switch self {
            case .active:      return Color(hex: "5B8DEF")
            case .stillDating: return Color(hex: "E8356D")
            case .serious:     return Color(hex: "00BFB3")
            case .faded:       return Color(hex: "9BA8BF")
            case .ended:       return Color(hex: "9BA8BF")
            case .friendzoned: return Color(hex: "F59E0B")
            }
        }
    }

    enum Source: String, Codable, CaseIterable {
        case hinge = "Hinge"
        case tinder = "Tinder"
        case bumble = "Bumble"
        case irl = "IRL"
        case friend = "Through Friends"
        case other = "Other"

        var icon: String {
            switch self {
            case .hinge: return "h.circle.fill"
            case .tinder: return "flame.fill"
            case .bumble: return "b.circle.fill"
            case .irl: return "figure.2.arms.open"
            case .friend: return "person.2.fill"
            case .other: return "ellipsis.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .hinge: return Color(hex: "E8604C")
            case .tinder: return Color(hex: "FF6B6B")
            case .bumble: return Color(hex: "F8B400")
            case .irl: return Color(hex: "4CAF89")
            case .friend: return Color(hex: "6B7FD7")
            case .other: return Color(hex: "8B8BA7")
            }
        }
    }

    enum Status: String, Codable, CaseIterable {
        case justMatched = "Just Matched"
        case inConversation = "In Conversation"
        case firstDatePending = "First Date Pending"
        case seeingEachOther = "Seeing Each Other"
        case gotSerious = "Got Serious"
        case itsComplicated = "It's Complicated"
        case takingABreak = "Taking a Break"
        case movedOn = "Moved On"
        case archived = "Archived"

        var color: Color {
            switch self {
            case .justMatched: return Color(hex: "6B7FD7")
            case .inConversation: return Color(hex: "4CAF89")
            case .firstDatePending: return Color(hex: "C8963E")
            case .seeingEachOther: return Color(hex: "E94560")
            case .gotSerious: return Color(hex: "00BFB3")
            case .itsComplicated: return Color(hex: "F59E0B")
            case .takingABreak: return Color(hex: "8B8BA7")
            case .movedOn: return Color(hex: "4A4A6A")
            case .archived: return Color(hex: "3A3A5A")
            }
        }

        var icon: String {
            switch self {
            case .justMatched: return "sparkles"
            case .inConversation: return "bubble.left.and.bubble.right.fill"
            case .firstDatePending: return "calendar.badge.clock"
            case .seeingEachOther: return "heart.fill"
            case .gotSerious: return "heart.circle.fill"
            case .itsComplicated: return "questionmark.circle.fill"
            case .takingABreak: return "pause.circle.fill"
            case .movedOn: return "arrow.forward.circle.fill"
            case .archived: return "archivebox.fill"
            }
        }

        var isActive: Bool {
            self != .movedOn && self != .archived
        }
    }
}



// MARK: - Conversation Intel

struct ConversationIntel: Codable, Identifiable {
    var id = UUID().uuidString
    var type: IntelType
    var headline: String
    var detail: String
    var urgency: Urgency

    enum IntelType: String, Codable {
        case pullback   = "pullback"
        case interest   = "interest"
        case redflag    = "redflag"
        case meetup     = "meetup"
        case mixed      = "mixed"
        case oversharing = "oversharing"
        case warning    = "warning"

        var icon: String {
            switch self {
            case .pullback:    return "thermometer.snowflake"
            case .interest:    return "flame.fill"
            case .redflag:     return "exclamationmark.triangle.fill"
            case .meetup:      return "calendar.badge.plus"
            case .mixed:       return "arrow.left.arrow.right"
            case .oversharing: return "hand.raised.fill"
            case .warning:     return "bell.badge.fill"
            }
        }

        var color: Color {
            switch self {
            case .pullback:    return Color(hex: "5B8DEF")
            case .interest:    return Color(hex: "00BFB3")
            case .redflag:     return Color(hex: "E8356D")
            case .meetup:      return Color(hex: "00BFB3")
            case .mixed:       return Color(hex: "F59E0B")
            case .oversharing: return Color(hex: "F59E0B")
            case .warning:     return Color(hex: "E8356D")
            }
        }
    }

    enum Urgency: String, Codable {
        case low, medium, high
    }
}


// MARK: - Date Suggestion

struct DateSuggestion: Codable, Identifiable {
    var id = UUID().uuidString
    var title: String
    var category: String
    var why: String
    var tip: String
    var searchQuery: String

    var venueCategory: VenueCategory {
        VenueCategory.allCases.first { $0.rawValue == category } ?? .other
    }
}

// MARK: - Date Entry

struct DateEntry: Codable, Identifiable {
    var id = UUID().uuidString
    var date = Date()
    var location = ""
    var rating = 0          // 1-5
    var notes = ""
    var wentWell = true
    var willSeeAgain: Bool? = nil
}

// MARK: - Archive Store

@Observable
class ArchiveStore {
    static let shared = ArchiveStore()
    var people: [Person] = []
    private let key = "archive_v1"

    // Stored as a .completeFileProtection file — encrypted when device is locked
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("archive_v1.json")
    }

    init() { load() }

    func load() {
        // One-time migration: move UserDefaults data to encrypted file storage
        if !FileManager.default.fileExists(atPath: fileURL.path),
           let data = UserDefaults.standard.data(forKey: key),
           let stored = try? JSONDecoder().decode([Person].self, from: data) {
            people = stored
            save()
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode([Person].self, from: data) else { return }
        people = stored
    }

    func save() {
        guard let data = try? JSONEncoder().encode(people) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func add(_ p: Person) { people.insert(p, at: 0); save() }
    func delete(_ p: Person) {
        ContactPhotoStore.shared.deleteAllPhotos(contactID: p.id)
        people.removeAll { $0.id == p.id }
        save()
    }
    func update(_ p: Person) {
        if let i = people.firstIndex(where: { $0.id == p.id }) { people[i] = p; save() }
    }
    func archive(_ p: Person) {
        var copy = p; copy.isArchived = true; copy.status = .archived; update(copy)
    }
    func restore(_ p: Person) {
        var copy = p; copy.isArchived = false; copy.status = .inConversation; update(copy)
    }

    var active: [Person] {
        people.filter { !$0.isArchived }
            .sorted { ($0.lastSpoke ?? $0.createdAt) > ($1.lastSpoke ?? $1.createdAt) }
    }
    var archived: [Person] { people.filter { $0.isArchived } }
}

// MARK: - Cyrano Models

struct CyranoSuggestion: Identifiable {
    var id = UUID()
    var text: String
    var tone: Tone
    var reasoning: String

    enum Tone: String, CaseIterable {
        case flirty = "Flirty"
        case casual = "Casual"
        case funny = "Funny"
        case thoughtful = "Thoughtful"
        case confident = "Confident"

        var icon: String {
            switch self {
            case .flirty: return "heart.fill"
            case .casual: return "hands.sparkles.fill"
            case .funny: return "face.smiling.fill"
            case .thoughtful: return "brain.head.profile"
            case .confident: return "bolt.fill"
            }
        }

        var color: Color {
            switch self {
            case .flirty: return .rwAccent
            case .casual: return Color(hex: "4CAF89")
            case .funny: return .rwGold
            case .thoughtful: return Color(hex: "6B7FD7")
            case .confident: return Color(hex: "E94560")
            }
        }
    }
}

// MARK: - Debrief Models

struct DateDebrief: Codable, Identifiable {
    var id = UUID().uuidString
    var personName = ""
    var dateNumber = 1
    var notes = ""
    var rating = 0
    var createdAt = Date()
    var analysis: Analysis? = nil

    struct Analysis: Codable {
        var greenFlags: [String] = []
        var yellowFlags: [String] = []
        var redFlags: [String] = []
        var recommendation: Rec = .maybe
        var suggestedMessage = ""
        var keyInsight = ""

        enum Rec: String, Codable {
            case pursue = "Pursue It"
            case maybe = "Wait and See"
            case pass = "Move On"

            var color: Color {
                switch self { case .pursue: return .rwSuccess; case .maybe: return .rwGold; case .pass: return .rwAccent }
            }
            var icon: String {
                switch self { case .pursue: return "arrow.forward.circle.fill"; case .maybe: return "clock.fill"; case .pass: return "xmark.circle.fill" }
            }
        }
    }
}

// MARK: - Debrief Store

@Observable
class DebriefStore {
    static let shared = DebriefStore()
    var debriefs: [DateDebrief] = []
    private let key = "debriefs_v1"

    // Stored as a .completeFileProtection file — encrypted when device is locked
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("debriefs_v1.json")
    }

    init() { load() }

    func load() {
        // One-time migration: move UserDefaults data to encrypted file storage
        if !FileManager.default.fileExists(atPath: fileURL.path),
           let data = UserDefaults.standard.data(forKey: key),
           let stored = try? JSONDecoder().decode([DateDebrief].self, from: data) {
            debriefs = stored
            save()
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode([DateDebrief].self, from: data) else { return }
        debriefs = stored
    }

    func save() {
        guard let data = try? JSONEncoder().encode(debriefs) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func add(_ d: DateDebrief) { debriefs.insert(d, at: 0); save() }
}

// MARK: - Keychain

struct Keychain {
    private static let service = Bundle.main.bundleIdentifier ?? "com.rowan.ai"

    // MARK: String helpers

    static func set(_ value: String, key: String) {
        setData(Data(value.utf8), key: key)
    }

    static func get(_ key: String) -> String? {
        guard let data = getData(key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: Data helpers (for Codable structs)

    static func setData(_ value: Data, key: String) {
        let query: [String: Any] = [
            kSecClass as String:          kSecClassGenericPassword,
            kSecAttrService as String:    service,
            kSecAttrAccount as String:    key,
            kSecValueData as String:      value,
            // Device-only, not backed up to iCloud, accessible only when device is unlocked
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func getData(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }

    @discardableResult
    static func delete(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}

// MARK: - Conversation Platform
// Covers every dating, social, messaging, and IRL platform the user might be
// having a conversation on. Grouped by category for the picker UI. Add new
// cases at the end of their category — order is significant for default sort.

enum ConversationPlatform: String, Codable, CaseIterable, Identifiable {

    // Major Dating Apps
    case hinge             = "Hinge"
    case bumble            = "Bumble"
    case tinder            = "Tinder"
    case match             = "Match"
    case okcupid           = "OkCupid"
    case coffeemeetsbagel  = "Coffee Meets Bagel"
    case thursday          = "Thursday"
    case feeld             = "Feeld"
    case theleague         = "The League"
    case hingevoice        = "Hinge Voice"
    case eharmony          = "eHarmony"
    case zoosk             = "Zoosk"
    case pof               = "Plenty of Fish"
    case badoo             = "Badoo"
    case happn             = "Happn"
    case jdate             = "JDate"
    case christianmingle   = "Christian Mingle"
    case silversingles     = "SilverSingles"
    case elitesingles      = "EliteSingles"
    case hily              = "Hily"
    case chispa            = "Chispa"
    case bbwcupid          = "BBW Cupid"
    case grindr            = "Grindr"
    case scruff            = "Scruff"
    case her               = "HER"
    case lex               = "Lex"
    case snack             = "Snack"
    case lox               = "The Lox Club"
    case raya              = "Raya"
    case inner             = "Inner Circle"
    case once              = "Once"
    case pickable          = "Pickable"
    case wingman           = "Wingman"
    case clover            = "Clover"
    case ship              = "Ship"
    case willow            = "Willow"
    case vibe              = "Vibe"
    case irl               = "IRL"
    case iris              = "Iris"
    case hud               = "HUD"
    case pure              = "Pure"
    case kippo             = "Kippo"
    case taimi             = "Taimi"
    case romeo             = "Romeo"
    case adam4adam         = "Adam4Adam"
    case recon             = "Recon"
    case chappy            = "Chappy"
    case surge             = "Surge"

    // Social Media
    case instagram = "Instagram"
    case snapchat  = "Snapchat"
    case twitter   = "Twitter/X"
    case facebook  = "Facebook"
    case tiktok    = "TikTok"
    case discord   = "Discord"
    case reddit    = "Reddit"
    case linkedin  = "LinkedIn"
    case pinterest = "Pinterest"
    case tumblr    = "Tumblr"
    case twitch    = "Twitch"
    case youtube   = "YouTube"
    case threads   = "Threads"
    case bereal    = "BeReal"
    case lemon8    = "Lemon8"
    case clubhouse = "Clubhouse"

    // Messaging
    case imessage   = "iMessage"
    case whatsapp   = "WhatsApp"
    case messenger  = "Messenger"
    case signal     = "Signal"
    case viber      = "Viber"
    case wechat     = "WeChat"
    case line       = "LINE"
    case kik        = "Kik"
    case skype      = "Skype"
    case zoom       = "Zoom"
    case facetime   = "FaceTime"
    case googleChat = "Google Chat"
    case telegram   = "Telegram"

    // IRL / Other
    case phone    = "Phone Call"
    case inPerson = "In Person"
    case email    = "Email"
    case other    = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .hinge, .hingevoice: return "heart.circle.fill"
        case .bumble: return "hexagon.fill"
        case .tinder: return "flame.fill"
        case .match, .eharmony, .elitesingles, .silversingles: return "person.2.circle.fill"
        case .okcupid: return "questionmark.circle.fill"
        case .coffeemeetsbagel: return "cup.and.saucer.fill"
        case .thursday: return "calendar.circle.fill"
        case .feeld: return "leaf.fill"
        case .theleague, .raya, .inner, .lox: return "crown.fill"
        case .instagram, .bereal: return "camera.fill"
        case .snapchat: return "camera.viewfinder"
        case .twitter: return "at"
        case .facebook, .messenger: return "person.crop.square.fill"
        case .tiktok, .snack: return "play.circle.fill"
        case .discord: return "headphones"
        case .reddit: return "bubble.left.and.bubble.right.fill"
        case .telegram, .signal, .viber, .kik: return "paperplane.fill"
        case .whatsapp, .line, .wechat: return "phone.bubble.left.fill"
        case .imessage: return "message.fill"
        case .phone, .facetime: return "phone.fill"
        case .inPerson: return "person.2.fill"
        case .zoom, .skype, .googleChat: return "video.fill"
        case .grindr, .scruff, .her, .lex, .taimi, .romeo, .adam4adam, .surge, .recon, .chappy: return "heart.fill"
        case .linkedin: return "briefcase.fill"
        case .email: return "envelope.fill"
        case .threads: return "at.circle.fill"
        case .clubhouse: return "mic.fill"
        case .twitch, .youtube: return "play.rectangle.fill"
        default: return "ellipsis.bubble.fill"
        }
    }

    /// Brand-evocative tint for the platform pill. Falls back to design-system
    /// gray for platforms without a strong brand color.
    var color: Color {
        switch self {
        case .hinge, .hingevoice:                 return Color(hex: "E8356D")
        case .bumble:                             return Color(hex: "F7B500")
        case .tinder:                             return Color(hex: "FF6B6B")
        case .match:                              return Color(hex: "0066CC")
        case .okcupid:                            return Color(hex: "0E4595")
        case .coffeemeetsbagel:                   return Color(hex: "8B4513")
        case .thursday:                           return Color(hex: "FF6E40")
        case .feeld:                              return Color(hex: "1E1E1E")
        case .theleague, .raya, .inner, .lox:     return Color(hex: "C0A020")
        case .eharmony:                           return Color(hex: "004F8B")
        case .zoosk:                              return Color(hex: "00ABE3")
        case .pof:                                return Color(hex: "F26C4F")
        case .badoo:                              return Color(hex: "8E44AD")
        case .happn:                              return Color(hex: "FE5667")
        case .jdate:                              return Color(hex: "1D5191")
        case .christianmingle:                    return Color(hex: "2A7DBF")
        case .silversingles, .elitesingles:       return Color(hex: "8B8BA7")
        case .hily:                               return Color(hex: "A1248F")
        case .chispa:                             return Color(hex: "E8356D")
        case .bbwcupid:                           return Color(hex: "C13584")
        case .grindr:                             return Color(hex: "F2D202")
        case .scruff:                             return Color(hex: "B57F30")
        case .her:                                return Color(hex: "9B59B6")
        case .lex:                                return Color(hex: "F5F5F5")
        case .snack:                              return Color(hex: "FF6B6B")
        case .once:                               return Color(hex: "F26C4F")
        case .pickable, .wingman:                 return Color(hex: "5B8DEF")
        case .clover, .ship, .willow, .vibe:      return Color(hex: "00BFB3")
        case .irl, .iris:                         return Color(hex: "E94560")
        case .hud, .pure:                         return Color(hex: "1E1E1E")
        case .kippo:                              return Color(hex: "9B59B6")
        case .taimi:                              return Color(hex: "00ABE3")
        case .romeo, .adam4adam, .recon, .chappy, .surge: return Color(hex: "1E1E1E")
        case .instagram:                          return Color(hex: "C13584")
        case .snapchat:                           return Color(hex: "FFFC00")
        case .imessage:                           return Color(hex: "34C759")
        case .whatsapp:                           return Color(hex: "25D366")
        case .phone:                              return Color(hex: "34C759")
        case .inPerson:                           return Color(hex: "00BFB3")
        case .twitter:                            return Color(hex: "1DA1F2")
        case .facebook:                           return Color(hex: "1877F2")
        case .messenger:                          return Color(hex: "0084FF")
        case .discord:                            return Color(hex: "5865F2")
        case .reddit:                             return Color(hex: "FF4500")
        case .tiktok:                             return Color(hex: "010101")
        case .telegram:                           return Color(hex: "0088CC")
        case .signal:                             return Color(hex: "3A76F0")
        case .linkedin:                           return Color(hex: "0A66C2")
        case .pinterest:                          return Color(hex: "E60023")
        case .tumblr:                             return Color(hex: "36465D")
        case .twitch:                             return Color(hex: "9146FF")
        case .youtube:                            return Color(hex: "FF0000")
        case .threads:                            return Color(hex: "010101")
        case .bereal:                             return Color(hex: "010101")
        case .lemon8:                             return Color(hex: "FFCB05")
        case .clubhouse:                          return Color(hex: "F1EFE4")
        case .viber:                              return Color(hex: "665CAC")
        case .wechat:                             return Color(hex: "07C160")
        case .line:                               return Color(hex: "00C300")
        case .kik:                                return Color(hex: "82BC23")
        case .skype:                              return Color(hex: "00AFF0")
        case .zoom:                               return Color(hex: "2D8CFF")
        case .facetime:                           return Color(hex: "4CD964")
        case .googleChat:                         return Color(hex: "1A73E8")
        case .email:                              return Color(hex: "5B8DEF")
        case .other:                              return Color.rwTextSecondary
        }
    }

    enum PlatformCategory: String, CaseIterable {
        case dating    = "Dating Apps"
        case social    = "Social Media"
        case messaging = "Messaging"
        case irl       = "In Real Life"
    }

    var category: PlatformCategory {
        switch self {
        case .hinge, .bumble, .tinder, .match, .okcupid, .coffeemeetsbagel, .thursday,
             .feeld, .theleague, .eharmony, .zoosk, .pof, .badoo, .happn, .jdate,
             .christianmingle, .silversingles, .elitesingles, .hily, .chispa, .grindr,
             .scruff, .her, .lex, .snack, .lox, .raya, .inner, .once, .pickable,
             .wingman, .clover, .ship, .willow, .vibe, .irl, .iris, .hud, .pure,
             .kippo, .taimi, .romeo, .adam4adam, .recon, .chappy, .surge, .bbwcupid,
             .hingevoice:
            return .dating
        case .instagram, .snapchat, .twitter, .facebook, .tiktok, .discord, .reddit,
             .linkedin, .pinterest, .tumblr, .twitch, .youtube, .threads, .bereal,
             .lemon8, .clubhouse:
            return .social
        case .imessage, .whatsapp, .messenger, .signal, .viber, .wechat, .line,
             .kik, .skype, .zoom, .facetime, .googleChat, .telegram:
            return .messaging
        case .phone, .inPerson, .email, .other:
            return .irl
        }
    }
}

// MARK: - Conversation Thread + Message

/// A single platform-bound exchange (e.g. all Hinge messages with this Person).
/// Multiple threads per contact represent the same person across different
/// platforms; the cross-platform timeline merges them chronologically.
struct ConversationThread: Codable, Identifiable {
    var id = UUID().uuidString
    var contactID: String
    var platform: ConversationPlatform
    var createdAt = Date()
    var lastActivityAt = Date()
    var messages: [ThreadMessage] = []
    var notes: String = ""
    var isActive: Bool = true
}

struct ThreadMessage: Codable, Identifiable {
    var id = UUID().uuidString
    var sender: MessageSender
    var text: String
    var timestamp = Date()
    var platform: ConversationPlatform

    enum MessageSender: String, Codable {
        case user = "Me"
        case them = "Them"
    }
}

// MARK: - Living Relationship Analysis
// Cyrano's running read on a connection. Regenerated whenever new data is added
// (rate-limited to once per hour by RelationshipAnalysisService unless the user
// taps Refresh manually). History is persisted so users can see the arc.

struct RelationshipAnalysis: Codable, Identifiable {
    var id = UUID().uuidString
    var contactID: String
    var lastUpdatedAt: Date = Date()
    var momentum: MomentumLevel
    var connectionStage: ConnectionStage
    var overallRead: String
    var greenFlags: [String] = []
    var yellowFlags: [String] = []
    var patterns: [String] = []
    var currentGuidance: String = ""
    var nextMoveAdvice: String = ""
    var dataPoints: Int = 0

    /// Snapshot of inputs used to generate this analysis — useful in the
    /// history sheet to show "based on N messages, M dates, K intel notes."
    var sourceMessageCount: Int = 0
    var sourceDateCount: Int = 0
    var sourceIntelCount: Int = 0

    enum MomentumLevel: String, Codable, CaseIterable {
        case building = "Building"
        case steady   = "Steady"
        case fading   = "Fading"
        case stalled  = "Stalled"
        case unclear  = "Too early to tell"

        var emoji: String {
            switch self {
            case .building: return "📈"
            case .steady:   return "➡️"
            case .fading:   return "📉"
            case .stalled:  return "⏸"
            case .unclear:  return "❓"
            }
        }

        var color: Color {
            switch self {
            case .building: return Color(hex: "00BFB3")
            case .steady:   return Color(hex: "5B8DEF")
            case .fading:   return Color(hex: "F59E0B")
            case .stalled:  return Color(hex: "9BA8BF")
            case .unclear:  return Color(hex: "E8356D")
            }
        }
    }

    enum ConnectionStage: String, Codable, CaseIterable {
        case justMet            = "Just Met"
        case earlyConversation  = "Early Conversation"
        case buildingRapport    = "Building Rapport"
        case clearInterest      = "Clear Interest"
        case dateTerritory      = "Date Territory"
        case dating             = "Dating"
        case exclusive          = "Getting Exclusive"
        case complicated        = "It's Complicated"
    }
}

// MARK: - Errors

enum RWError: LocalizedError {
    case parse, api, aiOff, crisisDetected, harmfulContent

    var errorDescription: String? {
        switch self {
        case .parse:          return "Could not read the AI response. Try again."
        case .api:            return "Cyrano is unavailable right now — try again in a moment."
        case .aiOff:          return "AI is off. Turn it on in Profile → Settings."
        case .crisisDetected: return "crisis"
        case .harmfulContent: return "harmful"
        }
    }
}
