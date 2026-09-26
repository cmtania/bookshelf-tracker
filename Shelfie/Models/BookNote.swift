import Foundation
import SwiftData

@Model
final class BookNote {
    var id: UUID = UUID()
    var text: String = ""
    var page: Int?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var book: Book?

    init(text: String = "", page: Int? = nil) {
        self.text = text
        self.page = page
    }
}
