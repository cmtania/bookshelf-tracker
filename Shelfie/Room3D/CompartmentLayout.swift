import Foundation

/// Where every book of one compartment goes, in compartment-local metres.
/// Shared by the 3D shelf and the 2D share image, so both always show the same arrangement.
struct CompartmentLayout {
    struct Entry {
        let book: BookSnapshot
        let dimensions: BookDimensions
        let placement: ShelfPacker.Placement
    }

    /// Gap between the compartment's left wall and the first book.
    static let inset: Float = 0.005

    let entries: [Entry]
    let hiddenCount: Int
    let packer: ShelfPacker

    init(_ compartment: CompartmentSnapshot, slot: CompartmentSlot) {
        let packer = ShelfPacker(innerWidth: slot.width - 2 * Self.inset, innerHeight: slot.height)
        let dimensions = Dictionary(
            compartment.books.map { ($0.id, BookDimensions(pages: $0.totalPages, id: $0.id)) },
            uniquingKeysWith: { first, _ in first }
        )
        let byID = Dictionary(compartment.books.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let items = compartment.books.compactMap { book -> ShelfPacker.Item? in
            guard let d = dimensions[book.id] else { return nil }
            return ShelfPacker.Item(id: book.id, thickness: d.thickness, lieFlat: book.status == .wantToRead)
        }
        let result = packer.pack(items)
        self.packer = packer
        self.hiddenCount = result.hiddenCount
        self.entries = result.placements.compactMap { placement in
            guard let book = byID[placement.id], let d = dimensions[placement.id] else { return nil }
            return Entry(book: book, dimensions: d, placement: placement)
        }
    }

    /// x of the book's centre (compartment-local). Lying books are centred in the stack area.
    func centerX(of entry: Entry) -> Float {
        if entry.placement.lying {
            return Self.inset + entry.placement.x + packer.stackFootprint / 2
        }
        return Self.inset + entry.placement.x + entry.dimensions.thickness / 2
    }

    /// y of the book's bottom (compartment-local).
    func bottomY(of entry: Entry) -> Float {
        entry.placement.lying ? entry.placement.y : 0
    }
}
