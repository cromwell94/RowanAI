import Foundation
import SwiftUI

// MARK: - Relationship

struct Relationship: Codable, Identifiable {
    var id = UUID().uuidString
    var partnerName = ""
    var partnerPersonId: String? = nil  // links to Archive person
    var startDate = Date()
    var anniversary: Date? = nil
    var milestones: [Milestone] = []
    var healthChecks: [HealthCheck] = []
    var vents: [Vent] = []
    var bucketList: [BucketItem] = []
    var notes = ""
    var createdAt = Date()

    var daysTogether: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
    }

    var weeksTogether: Int { daysTogether / 7 }
    var monthsTogether: Int {
        Calendar.current.dateComponents([.month], from: startDate, to: Date()).month ?? 0
    }
}

// MARK: - Milestone

struct Milestone: Codable, Identifiable {
    var id = UUID().uuidString
    var title = ""
    var date = Date()
    var notes = ""
    var isAnniversary = false
    var type: MType = .moment

    enum MType: String, Codable, CaseIterable {
        case firstDate    = "First Date"
        case official     = "Made It Official"
        case firstTrip    = "First Trip"
        case metFamily    = "Met the Family"
        case anniversary  = "Anniversary"
        case moment       = "Special Moment"
        case other        = "Other"

        var icon: String {
            switch self {
            case .firstDate:   return "heart.fill"
            case .official:    return "checkmark.seal.fill"
            case .firstTrip:   return "airplane"
            case .metFamily:   return "person.3.fill"
            case .anniversary: return "star.fill"
            case .moment:      return "sparkles"
            case .other:       return "calendar"
            }
        }

        var color: Color {
            switch self {
            case .firstDate:   return Color(hex: "E8356D")
            case .official:    return Color(hex: "00BFB3")
            case .firstTrip:   return Color(hex: "5B8DEF")
            case .metFamily:   return Color(hex: "F59E0B")
            case .anniversary: return Color(hex: "E8356D")
            case .moment:      return Color(hex: "9B59B6")
            case .other:       return Color(hex: "9BA8BF")
            }
        }
    }
}

// MARK: - Health Check

struct HealthCheck: Codable, Identifiable {
    var id = UUID().uuidString
    var date = Date()
    var scores: [String: Int] = [:]  // dimension: score 1-5
    var notes = ""
    var cyranoInsight = ""

    static let dimensions = [
        "Communication",
        "Quality Time",
        "Physical Affection",
        "Conflict Resolution",
        "Support & Appreciation",
        "Overall Happiness"
    ]

    var averageScore: Double {
        guard !scores.isEmpty else { return 0 }
        return Double(scores.values.reduce(0, +)) / Double(scores.count)
    }
}

// MARK: - Vent

struct Vent: Codable, Identifiable {
    var id = UUID().uuidString
    var content = ""
    var cyranoResponse = ""
    var createdAt = Date()
    var mood: Mood = .mixed

    enum Mood: String, Codable, CaseIterable {
        case happy    = "Happy"
        case anxious  = "Anxious"
        case sad      = "Sad"
        case confused = "Confused"
        case angry    = "Angry"
        case mixed    = "Mixed"

        var icon: String {
            switch self {
            case .happy:    return "face.smiling.fill"
            case .anxious:  return "waveform.path.ecg"
            case .sad:      return "cloud.rain.fill"
            case .confused: return "questionmark.circle.fill"
            case .angry:    return "flame.fill"
            case .mixed:    return "arrow.left.arrow.right"
            }
        }

        var color: Color {
            switch self {
            case .happy:    return Color(hex: "00BFB3")
            case .anxious:  return Color(hex: "F59E0B")
            case .sad:      return Color(hex: "5B8DEF")
            case .confused: return Color(hex: "9B59B6")
            case .angry:    return Color(hex: "E8356D")
            case .mixed:    return Color(hex: "9BA8BF")
            }
        }
    }
}

// MARK: - Bucket Item

struct BucketItem: Codable, Identifiable {
    var id = UUID().uuidString
    var title = ""
    var notes = ""
    var isDone = false
    var completedAt: Date? = nil
    var createdAt = Date()
}

// MARK: - Relationship Store

@Observable
class RelationshipStore {
    static let shared = RelationshipStore()
    var relationship: Relationship? = nil
    var isInRelationship: Bool { relationship != nil }
    private let legacyKey = "relationship_v1"

    // Stored as a .completeFileProtection file — encrypted when device is locked,
    // matching the protection level used by ArchiveStore and DebriefStore.
    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("relationship_v1.json")
    }

    init() { load() }

    func load() {
        // One-time migration: move UserDefaults data to encrypted file storage
        if !FileManager.default.fileExists(atPath: fileURL.path),
           let data = UserDefaults.standard.data(forKey: legacyKey),
           let stored = try? JSONDecoder().decode(Relationship.self, from: data) {
            relationship = stored
            save()
            UserDefaults.standard.removeObject(forKey: legacyKey)
            return
        }
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode(Relationship.self, from: data) else { return }
        relationship = stored
    }

    func save() {
        if let r = relationship {
            guard let data = try? JSONEncoder().encode(r) else { return }
            try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } else {
            // Relationship ended — remove the encrypted file
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    func startRelationship(partnerName: String, personId: String? = nil, startDate: Date = Date()) {
        relationship = Relationship(partnerName: partnerName, partnerPersonId: personId, startDate: startDate)
        save()
    }

    func update(_ block: (inout Relationship) -> Void) {
        guard var r = relationship else { return }
        block(&r)
        relationship = r
        save()
    }

    func endRelationship() {
        relationship = nil
        save() // removes the encrypted file
    }

    // Latest health check
    var latestHealthCheck: HealthCheck? {
        relationship?.healthChecks.sorted { $0.date > $1.date }.first
    }

    // Is it time for a health check? (weekly)
    var needsHealthCheck: Bool {
        guard let last = latestHealthCheck else { return true }
        let days = Calendar.current.dateComponents([.day], from: last.date, to: Date()).day ?? 0
        return days >= 7
    }

    // Date night needed? (if no wishlist venue visited in 2 weeks)
    var needsDateNight: Bool {
        let visited = WishlistStore.shared.visited
        guard let last = visited.sorted(by: { ($0.visitedAt ?? .distantPast) > ($1.visitedAt ?? .distantPast) }).first,
              let lastDate = last.visitedAt else { return true }
        let days = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        return days >= 14
    }
}
