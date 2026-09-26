import Foundation

/// Streak = consecutive local calendar days with at least one reading session.
/// If today has no session yet, the streak counts back from yesterday, so it only
/// breaks once a whole day passes without reading.
struct StreakCalculator {
    var calendar: Calendar = .current

    func currentStreak(_ dates: [Date], now: Date = .now) -> Int {
        let days = uniqueDays(dates)
        let today = calendar.startOfDay(for: now)
        var day = today
        if !days.contains(day) {
            guard let yesterday = previousDay(before: today) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = previousDay(before: day) else { break }
            day = previous
        }
        return count
    }

    func bestStreak(_ dates: [Date]) -> Int {
        let sorted = uniqueDays(dates).sorted()
        var best = 0
        var run = 0
        var previous: Date?
        for day in sorted {
            if let previous, let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

    func readToday(_ dates: [Date], now: Date = .now) -> Bool {
        dates.contains { calendar.isDate($0, inSameDayAs: now) }
    }

    private func uniqueDays(_ dates: [Date]) -> Set<Date> {
        Set(dates.map { calendar.startOfDay(for: $0) })
    }

    /// Re-normalised with startOfDay, so days that don't start at midnight (DST) still match.
    private func previousDay(before day: Date) -> Date? {
        calendar.date(byAdding: .day, value: -1, to: day).map { calendar.startOfDay(for: $0) }
    }
}
