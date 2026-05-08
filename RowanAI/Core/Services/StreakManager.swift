import SwiftUI
import UserNotifications

// MARK: - Streak Manager

@Observable
class StreakManager {
    static let shared = StreakManager()

    var currentStreak: Int {
        get { UserDefaults.standard.integer(forKey: "streak") }
        set { UserDefaults.standard.set(newValue, forKey: "streak") }
    }

    var longestStreak: Int {
        get { UserDefaults.standard.integer(forKey: "longestStreak") }
        set { UserDefaults.standard.set(newValue, forKey: "longestStreak") }
    }

    var lastActiveDate: Date? {
        get { UserDefaults.standard.object(forKey: "lastActiveDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "lastActiveDate") }
    }

    var skillScore: Int {
        get { UserDefaults.standard.integer(forKey: "skillScore") }
        set { UserDefaults.standard.set(newValue, forKey: "skillScore") }
    }

    var weeklyReplies: Int {
        get { UserDefaults.standard.integer(forKey: "weeklyReplies") }
        set { UserDefaults.standard.set(newValue, forKey: "weeklyReplies") }
    }

    var weeklyDebriefs: Int {
        get { UserDefaults.standard.integer(forKey: "weeklyDebriefs") }
        set { UserDefaults.standard.set(newValue, forKey: "weeklyDebriefs") }
    }

    var weeklyPractices: Int {
        get { UserDefaults.standard.integer(forKey: "weeklyPractices") }
        set { UserDefaults.standard.set(newValue, forKey: "weeklyPractices") }
    }

    // MARK: - Streak Logic

    func recordActivity() {
        let today = Calendar.current.startOfDay(for: Date())

        guard let last = lastActiveDate else {
            currentStreak = 1
            lastActiveDate = today
            longestStreak = max(longestStreak, currentStreak)
            return
        }

        let lastDay = Calendar.current.startOfDay(for: last)
        let diff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0

        switch diff {
        case 0: break // same day, no change
        case 1: // consecutive day
            currentStreak += 1
            lastActiveDate = today
            if currentStreak > longestStreak { longestStreak = currentStreak }
        default: // streak broken
            currentStreak = 1
            lastActiveDate = today
        }
    }

    func isStreakActive() -> Bool {
        guard let last = lastActiveDate else { return false }
        let lastDay = Calendar.current.startOfDay(for: last)
        let today = Calendar.current.startOfDay(for: Date())
        let diff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
        return diff <= 1
    }

    // MARK: - Skill Score

    func addPoints(_ points: Int, reason: String) {
        skillScore += points
        recordActivity()
        trackWeeklyActivity(reason: reason)
    }

    func trackWeeklyActivity(reason: String) {
        switch reason {
        case "reply":    weeklyReplies += 1
        case "debrief":  weeklyDebriefs += 1
        case "practice": weeklyPractices += 1
        default: break
        }
    }

    var skillLevel: String {
        switch skillScore {
        case 0..<50:     return "Beginner"
        case 50..<150:   return "Developing"
        case 150..<300:  return "Confident"
        case 300..<500:  return "Advanced"
        case 500..<1000: return "Expert"
        default:         return "Master"
        }
    }

    var skillLevelColor: Color {
        switch skillScore {
        case 0..<50:     return Color(hex: "9BA8BF")
        case 50..<150:   return Color(hex: "00BFB3")
        case 150..<300:  return Color(hex: "5B8DEF")
        case 300..<500:  return Color(hex: "E8356D")
        case 500..<1000: return Color(hex: "F59E0B")
        default:         return Color(hex: "F0387A")
        }
    }

    var nextLevelPoints: Int {
        switch skillScore {
        case 0..<50:     return 50
        case 50..<150:   return 150
        case 150..<300:  return 300
        case 300..<500:  return 500
        case 500..<1000: return 1000
        default:         return skillScore + 100
        }
    }

    var progressToNextLevel: Double {
        let prev: Int
        switch skillScore {
        case 0..<50:     prev = 0
        case 50..<150:   prev = 50
        case 150..<300:  prev = 150
        case 300..<500:  prev = 300
        case 500..<1000: prev = 500
        default:         return 1.0
        }
        let range = nextLevelPoints - prev
        let current = skillScore - prev
        return Double(current) / Double(range)
    }

    // MARK: - Weekly Reset (call on Monday)

    func checkWeeklyReset() {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let lastReset = UserDefaults.standard.object(forKey: "lastWeeklyReset") as? Date
        if weekday == 2 && (lastReset == nil || !Calendar.current.isDateInToday(lastReset!)) {
            weeklyReplies = 0; weeklyDebriefs = 0; weeklyPractices = 0
            UserDefaults.standard.set(Date(), forKey: "lastWeeklyReset")
        }
    }
}

// MARK: - Notification Manager

class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() async -> Bool {
        let granted = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
        return granted ?? false
    }

    // Schedule a match follow-up reminder
    func scheduleMatchReminder(personName: String, personId: String, daysUntil: Int = 4) {
        let content = UNMutableNotificationContent()
        content.title = "Don't let \(personName) go cold 🔥"
        content.body = "You haven't reached out in \(daysUntil) days. Want Cyrano to help?"
        content.sound = .default
        content.userInfo = ["personId": personId, "type": "matchReminder"]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: Double(daysUntil * 24 * 60 * 60), repeats: false)

        let request = UNNotificationRequest(
            identifier: "match_\(personId)",
            content: content,
            trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // Cancel reminder when user messages someone
    func cancelMatchReminder(personId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["match_\(personId)"])
    }

    // Daily streak reminder
    func scheduleDailyStreakReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyStreak"])

        let content = UNMutableNotificationContent()
        content.title = "Keep your streak going 🔥"
        content.body = "Open Rowan to maintain your \(StreakManager.shared.currentStreak)-day streak."
        content.sound = .default

        var components = DateComponents()
        components.hour = 19 // 7pm
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyStreak", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // Weekly insight notification
    func scheduleWeeklyInsight() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weeklyInsight"])

        let content = UNMutableNotificationContent()
        content.title = "Your weekly dating insights are ready 📊"
        content.body = "See how your confidence is growing this week."
        content.sound = .default

        var components = DateComponents()
        components.weekday = 1 // Sunday
        components.hour = 10

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "weeklyInsight", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Streak Card (for Home screen)

struct StreakCard: View {
    @State private var streak = StreakManager.shared
    @State private var showDetails = false

    var body: some View {
        Button { showDetails = true } label: {
            HStack(spacing: 14) {
                // Streak flame
                VStack(spacing: 2) {
                    Text(streak.isStreakActive() ? "🔥" : "💤")
                        .font(.system(size: 28))
                    Text("\(streak.currentStreak)")
                        .font(RWF.display(18))
                        .foregroundColor(streak.isStreakActive() ? Color(hex: "F59E0B") : .rwTextMuted)
                    Text("day\(streak.currentStreak == 1 ? "" : "s")")
                        .font(RWF.micro())
                        .foregroundColor(.rwTextMuted)
                }
                .frame(width: 56)

                Rectangle().fill(Color.rwBorder).frame(width: 1, height: 44)

                // Skill score
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Skill Score").font(RWF.cap()).foregroundColor(.rwTextSecondary)
                        Text(streak.skillLevel).font(RWF.micro())
                            .foregroundColor(streak.skillLevelColor)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(streak.skillLevelColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    HStack(spacing: 8) {
                        Text("\(streak.skillScore)").font(RWF.head(20)).foregroundColor(.rwTextPrimary)
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(Color.rwBorder).frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(LinearGradient.accent)
                                    .frame(width: geo.size.width * streak.progressToNextLevel, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                    Text("\(streak.nextLevelPoints - streak.skillScore) pts to \(nextLevelName)")
                        .font(RWF.micro()).foregroundColor(.rwTextMuted)
                }

                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.rwTextMuted).font(.system(size: 12))
            }
            .padding(SP.md).background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
            .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
        }
        .buttonStyle(SBS())
        .sheet(isPresented: $showDetails) { WeeklyInsightsView() }
    }

    var nextLevelName: String {
        switch streak.skillScore {
        case 0..<50:     return "Developing"
        case 50..<150:   return "Confident"
        case 150..<300:  return "Advanced"
        case 300..<500:  return "Expert"
        default:         return "Master"
        }
    }
}

// MARK: - Weekly Insights View

struct WeeklyInsightsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var streak = StreakManager.shared
    @State private var store = StoreManager.shared

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {

                    // Hero stat
                    VStack(spacing: 8) {
                        Text("\(streak.skillScore)")
                            .font(.system(size: 72, weight: .black, design: .rounded))
                            .foregroundStyle(LinearGradient.accent)
                        Text("Skill Score").font(RWF.body()).foregroundColor(.rwTextSecondary)
                        Text(streak.skillLevel).font(RWF.head(22)).foregroundColor(.rwTextPrimary)
                    }
                    .padding(.top, 20)

                    // Progress bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Progress to \(nextLevel)").font(RWF.cap()).foregroundColor(.rwTextSecondary)
                            Spacer()
                            Text("\(streak.nextLevelPoints - streak.skillScore) pts to go").font(RWF.cap()).foregroundColor(.rwTextMuted)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6).fill(Color.rwSurface).frame(height: 12)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(LinearGradient.accent)
                                    .frame(width: geo.size.width * streak.progressToNextLevel, height: 12)
                            }
                        }
                        .frame(height: 12)
                    }

                    RWLine()

                    // Streak
                    HStack {
                        VStack(spacing: 4) {
                            Text(streak.isStreakActive() ? "🔥" : "💤").font(.system(size: 36))
                            Text("\(streak.currentStreak)").font(RWF.display(28)).foregroundColor(.rwTextPrimary)
                            Text("Day Streak").font(RWF.cap()).foregroundColor(.rwTextSecondary)
                        }
                        Spacer()
                        VStack(spacing: 4) {
                            Text("🏆").font(.system(size: 36))
                            Text("\(streak.longestStreak)").font(RWF.display(28)).foregroundColor(.rwTextPrimary)
                            Text("Best Streak").font(RWF.cap()).foregroundColor(.rwTextSecondary)
                        }
                    }
                    .padding(SP.lg).background(Color.rwSurface)
                    .clipShape(RoundedRectangle(cornerRadius: RR.xl))

                    // This week
                    VStack(alignment: .leading, spacing: 14) {
                        Text("This Week").font(RWF.head()).foregroundColor(.rwTextPrimary)
                        HStack(spacing: 12) {
                            WeekStat(value: streak.weeklyReplies, label: "Replies", icon: "bubble.left.and.bubble.right.fill", color: Color(hex: "E8356D"))
                            WeekStat(value: streak.weeklyDebriefs, label: "Debriefs", icon: "doc.text.magnifyingglass", color: Color(hex: "5B8DEF"))
                            WeekStat(value: streak.weeklyPractices, label: "Practice", icon: "graduationcap.fill", color: Color(hex: "00BFB3"))
                        }
                    }

                    // Points guide
                    RWCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How to earn points").font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                            PointRow(icon: "bubble.left.and.bubble.right.fill", action: "Generate a Cyrano reply", points: "+5")
                            PointRow(icon: "doc.text.magnifyingglass", action: "Complete a Date Debrief", points: "+15")
                            PointRow(icon: "graduationcap.fill", action: "Finish a Practice scenario", points: "+20")
                            PointRow(icon: "bolt.fill", action: "Complete a Challenge", points: "+10")
                            PointRow(icon: "book.fill", action: "Read all lessons in a category", points: "+25")
                            PointRow(icon: "flame.fill", action: "7-day streak bonus", points: "+50")
                        }
                    }

                    if !store.isPro {
                        ProNudge()
                    }

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, SP.lg)
            }
            .rwBG()
            .navigationTitle("Your Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.rwAccent)
                }
            }
        }
    }

    var nextLevel: String {
        switch streak.skillScore {
        case 0..<50:     return "Developing"
        case 50..<150:   return "Confident"
        case 150..<300:  return "Advanced"
        case 300..<500:  return "Expert"
        default:         return "Master"
        }
    }
}

struct WeekStat: View {
    let value: Int; let label: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                .foregroundColor(color).frame(width: 44, height: 44)
                .background(color.opacity(0.1)).clipShape(Circle())
            Text("\(value)").font(RWF.display(22)).foregroundColor(.rwTextPrimary)
            Text(label).font(RWF.cap(11)).foregroundColor(.rwTextSecondary)
        }
        .frame(maxWidth: .infinity).padding(SP.md)
        .background(Color.rwSurface)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
    }
}

struct PointRow: View {
    let icon: String; let action: String; let points: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                .foregroundColor(.rwTextSecondary).frame(width: 20)
            Text(action).font(RWF.body(14)).foregroundColor(.rwTextSecondary)
            Spacer()
            Text(points).font(RWF.head(14)).foregroundStyle(LinearGradient.accent)
        }
    }
}

struct ProNudge: View {
    @State private var showPaywall = false
    var body: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "crown.fill").font(.system(size: 20))
                    .foregroundStyle(LinearGradient.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Go Pro to unlock everything").font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                    Text("Unlimited coaching, all scenarios, weekly insights.").font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
            }
            .padding(SP.md).background(Color.rwSurface)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
        }
        .buttonStyle(SBS())
        .sheet(isPresented: $showPaywall) { PaywallView(reason: .upgrade) }
    }
}
