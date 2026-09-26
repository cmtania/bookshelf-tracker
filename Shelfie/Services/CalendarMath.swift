import Foundation

enum CalendarMath {
    static func startOfMonth(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// Cells for a month grid: leading `nil`s up to the first weekday, then one date per day.
    static func monthCells(for month: Date, calendar: Calendar = .current) -> [Date?] {
        let start = startOfMonth(month, calendar: calendar)
        let weekday = calendar.component(.weekday, from: start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let dayCount = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: start).map { calendar.startOfDay(for: $0) })
        }
        return cells
    }

    /// Very short weekday symbols, starting at the locale's first weekday.
    static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }
}
