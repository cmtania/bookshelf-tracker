import Foundation
import SwiftData
import UserNotifications

/// What the scheduler needs to know about a book (plain values, so planning is testable).
struct ReminderBook: Equatable {
    var title: String
    var isReading: Bool
    var remindersOn: Bool
    var sessionDates: [Date]
}

struct PlannedReminder: Equatable {
    var id: String
    var date: Date
    var title: String
    var body: String
}

/// Local notifications only. At most 7 daily reminders + 2 streak alerts are pending at once,
/// far below iOS's 64-request limit. Everything is re-planned on launch/foreground and after edits.
enum ReminderScheduler {
    static let idPrefix = "shelfie."
    static let dailyDays = 7

    static var allIDs: [String] {
        (0..<dailyDays).map { "\(idPrefix)daily.\($0)" } + ["\(idPrefix)streak.0", "\(idPrefix)streak.1"]
    }

    static func plan(
        books: [ReminderBook],
        dailyEnabled: Bool,
        dailyMinutes: Int,
        streakEnabled: Bool,
        streakMinutes: Int = Prefs.streakAlertMinutes,
        now: Date,
        calendar: Calendar = .current
    ) -> [PlannedReminder] {
        let streaks = StreakCalculator(calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let tracked = books.filter { $0.isReading && $0.remindersOn }
        var result: [PlannedReminder] = []

        func time(dayOffset: Int, minutes: Int) -> Date? {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { return nil }
            return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day)
        }

        // Daily nudge for the next 7 days; today's is skipped once every tracked book was read today.
        if dailyEnabled, !tracked.isEmpty {
            let allReadToday = tracked.allSatisfy { streaks.readToday($0.sessionDates, now: now) }
            let names = listNames(tracked.map(\.title))
            for offset in 0..<dailyDays {
                guard let date = time(dayOffset: offset, minutes: dailyMinutes), date > now else { continue }
                if offset == 0 && allReadToday { continue }
                result.append(PlannedReminder(
                    id: "\(idPrefix)daily.\(offset)",
                    date: date,
                    title: "Time to read",
                    body: "Pick up \(names) where you left off."
                ))
            }
        }

        if streakEnabled {
            // Tonight: books whose streak is still alive from yesterday but haven't been read today.
            let atRisk = tracked.filter {
                !streaks.readToday($0.sessionDates, now: now) && streaks.currentStreak($0.sessionDates, now: now) > 0
            }
            if !atRisk.isEmpty, let date = time(dayOffset: 0, minutes: streakMinutes), date > now {
                result.append(PlannedReminder(
                    id: "\(idPrefix)streak.0",
                    date: date,
                    title: "Don't break your streak 🔥",
                    body: streakBody(atRisk, streaks: streaks, now: now)
                ))
            }
            // Tomorrow night: books read today will be at risk then (in case the app isn't opened tomorrow).
            let readToday = tracked.filter { streaks.readToday($0.sessionDates, now: now) }
            if !readToday.isEmpty, let date = time(dayOffset: 1, minutes: streakMinutes) {
                result.append(PlannedReminder(
                    id: "\(idPrefix)streak.1",
                    date: date,
                    title: "Keep your streak going 🔥",
                    body: streakBody(readToday, streaks: streaks, now: now)
                ))
            }
        }
        return result
    }

    @MainActor
    static func reschedule(context: ModelContext) async {
        let books = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        let snapshot = books.map {
            ReminderBook(title: $0.title, isReading: $0.status == .reading, remindersOn: $0.remindersOn, sessionDates: $0.sessionDates)
        }
        let planned = plan(
            books: snapshot,
            dailyEnabled: Prefs.remindersEnabled,
            dailyMinutes: Prefs.reminderMinutes,
            streakEnabled: Prefs.streakAlertEnabled,
            now: .now
        )
        await apply(planned)
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    private static func apply(_ planned: [PlannedReminder]) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: allIDs)
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        default:
            return
        }
        for reminder in planned {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }

    private static func streakBody(_ books: [ReminderBook], streaks: StreakCalculator, now: Date) -> String {
        if books.count == 1, let book = books.first {
            let days = streaks.currentStreak(book.sessionDates, now: now)
            return "Read a few pages of \(book.title) to keep your \(days)-day streak."
        }
        return "\(listNames(books.map(\.title))) have streaks waiting for you."
    }

    static func listNames(_ names: [String]) -> String {
        switch names.count {
        case 0: return "your book"
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default: return "\(names[0]), \(names[1]) and \(names.count - 2) more"
        }
    }
}
