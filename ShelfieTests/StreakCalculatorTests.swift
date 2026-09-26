import Foundation
import Testing
@testable import Shelfie

struct StreakCalculatorTests {
    let calc = StreakCalculator(calendar: TestCalendar.newYork)

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        TestCalendar.date(y, m, d, h, min)
    }

    @Test func noSessionsIsZero() {
        #expect(calc.currentStreak([], now: date(2026, 9, 26)) == 0)
        #expect(calc.bestStreak([]) == 0)
    }

    @Test func readTodayCountsOne() {
        #expect(calc.currentStreak([date(2026, 9, 26, 8)], now: date(2026, 9, 26, 20)) == 1)
    }

    @Test func streakSurvivesUntilTheDayEnds() {
        let dates = [date(2026, 9, 24), date(2026, 9, 25)]
        #expect(calc.currentStreak(dates, now: date(2026, 9, 26, 23, 30)) == 2)
    }

    @Test func missedDayBreaksStreak() {
        let dates = [date(2026, 9, 22), date(2026, 9, 23), date(2026, 9, 25)]
        #expect(calc.currentStreak(dates, now: date(2026, 9, 26)) == 1)
        #expect(calc.currentStreak([date(2026, 9, 23)], now: date(2026, 9, 26)) == 0)
    }

    @Test func severalSessionsInOneDayCountOnce() {
        let dates = [date(2026, 9, 26, 7), date(2026, 9, 26, 13), date(2026, 9, 26, 22), date(2026, 9, 25, 23, 59)]
        #expect(calc.currentStreak(dates, now: date(2026, 9, 26, 23)) == 2)
    }

    @Test func midnightSplitsDays() {
        let dates = [date(2026, 9, 25, 23, 59), date(2026, 9, 26, 0, 1)]
        #expect(calc.currentStreak(dates, now: date(2026, 9, 26, 9)) == 2)
    }

    @Test func acrossDaylightSavingStart() {
        // US clocks spring forward on 2026-03-08.
        let dates = [date(2026, 3, 7), date(2026, 3, 8), date(2026, 3, 9)]
        #expect(calc.currentStreak(dates, now: date(2026, 3, 9, 18)) == 3)
        #expect(calc.bestStreak(dates) == 3)
    }

    @Test func acrossDaylightSavingEnd() {
        // US clocks fall back on 2026-11-01.
        let dates = [date(2026, 10, 31, 23), date(2026, 11, 1, 1), date(2026, 11, 2, 0, 30)]
        #expect(calc.currentStreak(dates, now: date(2026, 11, 2, 8)) == 3)
    }

    @Test func bestStreakFindsLongestRun() {
        let dates = [1, 2, 3, 6, 7, 8, 9, 12].map { date(2026, 8, $0) }
        #expect(calc.bestStreak(dates) == 4)
    }

    @Test func readToday() {
        #expect(calc.readToday([date(2026, 9, 26, 6)], now: date(2026, 9, 26, 22)))
        #expect(!calc.readToday([date(2026, 9, 25, 23)], now: date(2026, 9, 26, 1)))
    }
}
