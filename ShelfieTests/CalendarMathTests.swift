import Foundation
import Testing
@testable import Shelfie

struct CalendarMathTests {
    // 1 September 2026 is a Tuesday.
    @Test func sundayFirstWeek() {
        var calendar = TestCalendar.newYork
        calendar.firstWeekday = 1
        let cells = CalendarMath.monthCells(for: TestCalendar.date(2026, 9, 15), calendar: calendar)
        #expect(cells.prefix(2).allSatisfy { $0 == nil })
        #expect(cells[2] == TestCalendar.date(2026, 9, 1, 0))
        #expect(cells.count == 2 + 30)
        #expect(CalendarMath.weekdaySymbols(calendar: calendar).first == "S")
    }

    // 26 September 2026 is a Saturday.
    @Test func weekContainingADayFollowsTheFirstWeekday() {
        var calendar = TestCalendar.newYork
        calendar.firstWeekday = 1
        let sundayWeek = CalendarMath.weekDays(containing: TestCalendar.date(2026, 9, 26), calendar: calendar)
        #expect(sundayWeek.count == 7)
        #expect(sundayWeek.first == TestCalendar.date(2026, 9, 20, 0))
        #expect(sundayWeek.last == TestCalendar.date(2026, 9, 26, 0))

        calendar.firstWeekday = 2
        let mondayWeek = CalendarMath.weekDays(containing: TestCalendar.date(2026, 9, 26), calendar: calendar)
        #expect(mondayWeek.first == TestCalendar.date(2026, 9, 21, 0))
        #expect(mondayWeek.last == TestCalendar.date(2026, 9, 27, 0))
    }

    @Test func weekAcrossAMonthBoundary() {
        var calendar = TestCalendar.newYork
        calendar.firstWeekday = 1
        // Wed 30 Sep 2026 -> Sun 27 Sep ... Sat 3 Oct
        let week = CalendarMath.weekDays(containing: TestCalendar.date(2026, 9, 30), calendar: calendar)
        #expect(week.first == TestCalendar.date(2026, 9, 27, 0))
        #expect(week.last == TestCalendar.date(2026, 10, 3, 0))
    }

    @Test func mondayFirstWeek() {
        var calendar = TestCalendar.newYork
        calendar.firstWeekday = 2
        let cells = CalendarMath.monthCells(for: TestCalendar.date(2026, 9, 15), calendar: calendar)
        #expect(cells.first! == nil)
        #expect(cells[1] == TestCalendar.date(2026, 9, 1, 0))
        #expect(cells.count == 1 + 30)
        #expect(CalendarMath.weekdaySymbols(calendar: calendar).first == "M")
    }
}
