import Foundation

/// Plain-value copy of what the 3D shelf shows. The scene rebuilds only when this changes.
struct BookSnapshot: Equatable, Identifiable {
    var id: UUID
    var title: String
    var author: String
    var totalPages: Int
    var status: ReadingStatus
    var spineColorHex: String
}

struct CompartmentSnapshot: Equatable {
    var index: Int
    var categoryID: UUID?
    var name: String?
    var books: [BookSnapshot]

    var isEmpty: Bool { categoryID == nil }
}

struct ShelfSnapshot: Equatable {
    var compartments: [CompartmentSnapshot]

    /// Compartment i holds the i-th category by sortIndex; the rest are empty.
    @MainActor
    static func make(categories: [BookCategory], books: [Book]) -> ShelfSnapshot {
        let sortedCategories = categories.sorted { $0.sortIndex < $1.sortIndex }
        let sortedBooks = books.sorted {
            ($0.shelfOrder, $0.createdAt) < ($1.shelfOrder, $1.createdAt)
        }
        let compartments = (0..<BookcaseGeometry.compartmentCount).map { index -> CompartmentSnapshot in
            guard index < sortedCategories.count else {
                return CompartmentSnapshot(index: index, categoryID: nil, name: nil, books: [])
            }
            let category = sortedCategories[index]
            let shelfBooks = sortedBooks
                .filter { $0.category?.id == category.id }
                .map {
                    BookSnapshot(
                        id: $0.id,
                        title: $0.title,
                        author: $0.author,
                        totalPages: $0.totalPages,
                        status: $0.status,
                        spineColorHex: $0.spineColorHex
                    )
                }
            return CompartmentSnapshot(index: index, categoryID: category.id, name: category.name, books: shelfBooks)
        }
        return ShelfSnapshot(compartments: compartments)
    }
}
