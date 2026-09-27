import Foundation

/// The numbers shown for a category in the Categories tab.
struct CategoryStats {
    let bookCount: Int
    let reading: Int
    let finished: Int
    let wantToRead: Int
    /// Pages read across the category's books (each book capped at its page count).
    let pagesRead: Int
    let totalPages: Int
    /// Days in a row with reading logged for any book in the category.
    let streak: Int
    let lastRead: Date?
    let pagesThisWeek: Int
    /// Books currently being read, most recently read first.
    let nowReading: [Book]

    var progress: Double {
        totalPages > 0 ? Double(pagesRead) / Double(totalPages) : 0
    }

    @MainActor
    init(_ category: BookCategory, calendar: Calendar = .current, now: Date = .now) {
        let books = category.books ?? []
        let sessionDates = books.flatMap(\.sessionDates)
        bookCount = books.count
        reading = books.filter { $0.status == .reading }.count
        finished = books.filter { $0.status == .finished }.count
        wantToRead = books.filter { $0.status == .wantToRead }.count
        pagesRead = books.reduce(0) { $0 + min(max(0, $1.currentPage), $1.totalPages) }
        totalPages = books.reduce(0) { $0 + $1.totalPages }
        streak = StreakCalculator(calendar: calendar).currentStreak(sessionDates, now: now)
        lastRead = sessionDates.max()
        pagesThisWeek = books
            .flatMap { $0.sessions ?? [] }
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }
            .reduce(0) { $0 + $1.pagesRead }
        nowReading = books
            .filter { $0.status == .reading }
            .sorted { ($0.sessionDates.max() ?? $0.createdAt) > ($1.sessionDates.max() ?? $1.createdAt) }
    }

    /// Where the category's compartment is on the bookcase, e.g. "Top shelf · left".
    static func position(ofIndex index: Int) -> String {
        let rows = ["Top shelf", "2nd shelf", "Middle shelf", "4th shelf", "Bottom shelf"]
        let row = index / BookcaseGeometry.columns
        guard row < rows.count else { return "Not on the shelf" }
        return "\(rows[row]) · \(index % BookcaseGeometry.columns == 0 ? "left" : "right")"
    }
}
