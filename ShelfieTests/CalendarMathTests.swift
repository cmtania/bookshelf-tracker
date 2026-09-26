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
