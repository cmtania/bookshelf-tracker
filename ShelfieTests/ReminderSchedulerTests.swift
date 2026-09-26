import Foundation
import Testing
@testable import Shelfie

struct ReminderSchedulerTests {
    let calendar = TestCalendar.newYork

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        TestCalendar.date(y, m, d, h, min)
    }

    func book(_ title: String = "Dune", reading: Bool = true, reminders: Bool = true, sessions: [Date] = []) -> ReminderBook {
        ReminderBook(title: title, isReading: reading, remindersOn: reminders, sessionDates: sessions)
    }

    func plan(_ books: [ReminderBook], now: Date, daily: Bool = true, streak: Bool = true) -> [PlannedReminder] {
        ReminderScheduler.plan(
            books: books,
            dailyEnabled: daily,
            dailyMinutes: 19 * 60,
            streakEnabled: streak,
            streakMinutes: 20 * 60,
            now: now,
            calendar: calendar
        )
    }

    @Test func dailyRemindersForTheNextSevenDays() {
        let result = plan([book()], now: date(2026, 9, 26, 10))
        let daily = result.filter { $0.id.contains("daily") }
        #expect(daily.count == 7)
        #expect(daily.first?.date == date(2026, 9, 26, 19))
        #expect(daily.last?.date == date(2026, 10, 2, 19))
        #expect(result.filter { $0.id.contains("streak") }.isEmpty)
    }

    @Test func todaysReminderIsSkippedOnceRead() {
        let result = plan([book(sessions: [date(2026, 9, 26, 8)])], now: date(2026, 9, 26, 10))
        let daily = result.filter { $0.id.contains("daily") }
        #expect(daily.count == 6)
        #expect(daily.first?.date == date(2026, 9, 27, 19))
        #expect(result.contains { $0.id == "shelfie.streak.1" && $0.date == date(2026, 9, 27, 20) })
        #expect(!result.contains { $0.id == "shelfie.streak.0" })
    }

    @Test func streakAtRiskTonight() {
        let sessions = [date(2026, 9, 24), date(2026, 9, 25)]
        let result = plan([book(sessions: sessions)], now: date(2026, 9, 26, 10))
        let tonight = result.first { $0.id == "shelfie.streak.0" }
        #expect(tonight?.date == date(2026, 9, 26, 20))
        #expect(tonight?.body.contains("2-day") == true)
    }

    @Test func nothingIsScheduledInThePast() {
        let sessions = [date(2026, 9, 24), date(2026, 9, 25)]
        let now = date(2026, 9, 26, 21)
        let result = plan([book(sessions: sessions)], now: now)
        #expect(!result.contains { $0.id == "shelfie.streak.0" })
        #expect(result.allSatisfy { $0.date > now })
        #expect(result.filter { $0.id.contains("daily") }.first?.date == date(2026, 9, 27, 19))
    }

    @Test func respectsTogglesAndStatus() {
        let now = date(2026, 9, 26, 10)
        let sessions = [date(2026, 9, 25)]
        #expect(plan([book(reminders: false, sessions: sessions)], now: now).isEmpty)
        #expect(plan([book(reading: false, sessions: sessions)], now: now).isEmpty)
        #expect(plan([book(sessions: sessions)], now: now, daily: false, streak: false).isEmpty)
        #expect(plan([book(sessions: sessions)], now: now, daily: false).allSatisfy { $0.id.contains("streak") })
    }

    @Test func manyBooksStayFarBelowTheSystemLimit() {
        let now = date(2026, 9, 26, 10)
        let books = (0..<80).map { i in
            book("Book \(i)", sessions: i.isMultiple(of: 2) ? [date(2026, 9, 26, 8)] : [date(2026, 9, 25)])
        }
        let result = plan(books, now: now)
        #expect(result.count <= ReminderScheduler.allIDs.count)
        #expect(result.count < 64)
        #expect(Set(result.map(\.id)).count == result.count)
    }

    @Test func listNames() {
        #expect(ReminderScheduler.listNames(["Dune"]) == "Dune")
        #expect(ReminderScheduler.listNames(["Dune", "Emma"]) == "Dune and Emma")
        #expect(ReminderScheduler.listNames(["Dune", "Emma", "Ulysses", "Beloved"]) == "Dune, Emma and 2 more")
    }
}
