import Foundation
import SwiftData

/// A category is one compartment of the bookcase; `sortIndex` decides which one.
@Model
final class BookCategory {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#1F6F6B"
    var sortIndex: Int = 0

    // Nullify rather than cascade: the UI refuses to delete a category that still has books,
    // so deleting a category can never silently delete books.
    @Relationship(deleteRule: .nullify, inverse: \Book.category)
    var books: [Book]? = []

    init(name: String = "", colorHex: String = "#1F6F6B", sortIndex: Int = 0) {
        self.name = name
        self.colorHex = colorHex
        self.sortIndex = sortIndex
    }

    var bookCount: Int { books?.count ?? 0 }
}
