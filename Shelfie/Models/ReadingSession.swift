import Foundation
import SwiftData

@Model
final class ReadingSession {
    var id: UUID = UUID()
    var date: Date = Date()
    var fromPage: Int = 0
    var toPage: Int = 0
    var minutes: Int?

    var book: Book?

    // Relationships are set after insert (see LogReadingSheet), not in init.
    init(date: Date = .now, fromPage: Int = 0, toPage: Int = 0, minutes: Int? = nil) {
        self.date = date
        self.fromPage = fromPage
        self.toPage = toPage
        self.minutes = minutes
    }

    var pagesRead: Int { max(0, toPage - fromPage) }
}
