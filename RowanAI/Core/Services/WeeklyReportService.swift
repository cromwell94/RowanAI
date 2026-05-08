import Foundation
import UserNotifications

// MARK: - Weekly Connection Report (Build 1 Step 12 stub)
// Sunday 6pm local time push. Full Cyrano-generated letter ships in Build 4;
// for now this service ensures the schedule is wired and the persistence
// shape is in place so subsequent builds can fill in content without churn.

struct WeeklyReport: Codable, Identifiable {
    var id = UUID().uuidString
    var weekEnding: Date = Date()
    var win: String = ""
    var focus: String = ""
    // Pro-only fields — empty for free users in Build 4
    var observation: String = ""
    var researchInsight: String = ""
    var riScoreDelta: Int = 0
}

@Observable
final class WeeklyReportService {
    static let shared = WeeklyReportService()

    var reports: [WeeklyReport] = []

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("weekly_reports_v1.json")
    }

    private static let notificationID = "rowan.weekly.connection.report"

    init() { load() }

    // Schedules a recurring weekly local notification for Sunday 6pm.
    // Idempotent — pending requests with the same identifier are replaced.
    func scheduleSundayReminder() {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Your weekly connection report is ready."
        content.body  = "Tap to read this week's letter from Cyrano."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = 1   // Sunday (Calendar.current.firstWeekday is locale-independent for triggers)
        dateComponents.hour    = 18  // 6pm local

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Self.notificationID,
                                            content: content,
                                            trigger: trigger)
        center.add(request)
    }

    func cancelSundayReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    func add(_ report: WeeklyReport) {
        reports.insert(report, at: 0)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode([WeeklyReport].self, from: data)
        else { return }
        reports = stored
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(reports) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
