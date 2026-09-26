import Foundation
import Testing
@testable import Shelfie

struct ShelfPackerTests {
    // Same size as a real compartment (BookcaseGeometry: 0.7625 wide, 0.358 tall).
    let packer = ShelfPacker(innerWidth: 0.7625, innerHeight: 0.338)

    func items(_ count: Int, thickness: Float = 0.03, flat: Bool = false) -> [ShelfPacker.Item] {
        (0..<count).map { _ in ShelfPacker.Item(id: UUID(), thickness: thickness, lieFlat: flat) }
    }

    @Test func booksThatFitStandUprightInOrder() {
        let input = items(10)
        let result = packer.pack(input)
        #expect(result.hiddenCount == 0)
        #expect(result.placements.map(\.id) == input.map(\.id))
        #expect(result.placements.allSatisfy { !$0.lying && $0.y == 0 })
        let xs = result.placements.map(\.x)
        #expect(xs == xs.sorted())
        #expect((xs.last ?? 0) + 0.03 <= 0.7625)
    }

    @Test func wantToReadBooksLieFlatAtTheRightEnd() {
        let result = packer.pack(items(3) + items(2, flat: true))
        let lying = result.placements.filter(\.lying)
        let upright = result.placements.filter { !$0.lying }
        #expect(lying.count == 2)
        #expect(upright.count == 3)
        #expect(lying.allSatisfy { abs($0.x - (0.7625 - packer.stackFootprint)) < 0.0001 })
        #expect(lying.map(\.y) == [0, 0.03])
        #expect(upright.allSatisfy { $0.x + 0.03 <= 0.7625 - packer.stackFootprint })
    }

    @Test func overflowGoesOnTheStackThenIsCounted() {
        let result = packer.pack(items(30))
        let upright = result.placements.filter { !$0.lying }
        let lying = result.placements.filter(\.lying)
        // Upright space is 0.7625 - 0.27 = 0.4925 → 15 books; stack height 0.318 → 10 books.
        #expect(upright.count == 15)
        #expect(lying.count == 10)
        #expect(result.hiddenCount == 5)
    }

    @Test func emptyCompartment() {
        let result = packer.pack([])
        #expect(result.placements.isEmpty)
        #expect(result.hiddenCount == 0)
    }

    @Test func bookDimensionsStayInsideACompartment() {
        let geometry = BookcaseGeometry()
        for pages in [1, 50, 300, 1200, 5000] {
            let d = BookDimensions(pages: pages, id: UUID())
            #expect(d.thickness >= 0.012 && d.thickness <= 0.075)
            #expect(d.height < geometry.rowHeight)
            #expect(d.depth < geometry.depth)
            #expect(d.height < packer.stackFootprint)
        }
    }
}
