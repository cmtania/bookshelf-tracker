import Foundation
import Testing
@testable import Shelfie

/// Every bookcase design must hold the same 10 categories and fit real books.
struct BookcaseStyleTests {
    // Largest book: 0.25 m tall, 0.176 m deep, plus the 3 cm a "Reading" book sticks out.
    let tallestBook: Float = 0.25
    let deepestBook: Float = 0.176 + 0.03 + 0.012

    @Test(arguments: BookcaseStyle.allCases)
    func hasTenCompartmentsThatFitBooks(_ style: BookcaseStyle) {
        let layout = style.layout
        #expect(layout.slots.count == BookcaseGeometry.compartmentCount)
        for slot in layout.slots {
            #expect(slot.height >= tallestBook, "\(style.name): a compartment is too low for tall books")
            #expect(slot.depth >= deepestBook, "\(style.name): a compartment is too shallow")
            #expect(slot.width >= 0.3, "\(style.name): a compartment is too narrow")
            #expect(BookcaseFactory.labelWidth(for: slot) > 0.2, "\(style.name): no room for a category label")
        }
    }

    @Test(arguments: BookcaseStyle.allCases)
    func compartmentsDontOverlap(_ style: BookcaseStyle) {
        let slots = style.layout.slots
        for i in slots.indices {
            for j in slots.indices where j > i {
                let a = slots[i], b = slots[j]
                let overlapX = a.origin.x < b.origin.x + b.width && b.origin.x < a.origin.x + a.width
                let overlapY = a.origin.y < b.origin.y + b.height && b.origin.y < a.origin.y + a.height
                #expect(!(overlapX && overlapY), "\(style.name): compartments \(i) and \(j) overlap")
            }
        }
    }

    @Test(arguments: BookcaseStyle.allCases)
    func compartmentsAreInsideTheFramedArea(_ style: BookcaseStyle) {
        let layout = style.layout
        for slot in layout.slots {
            #expect(slot.origin.x >= layout.minX && slot.origin.x + slot.width <= layout.maxX)
            #expect(slot.origin.y >= layout.minY && slot.origin.y + slot.height <= layout.maxY)
        }
        #expect(layout.width > 0 && layout.height > 0)
        #expect(!layout.pieces.isEmpty)
    }

    @Test func compartmentsAreInReadingOrder() {
        // Top row first: compartment 0 is never lower than compartment 9, in every design.
        for style in BookcaseStyle.allCases {
            let slots = style.layout.slots
            #expect(slots[0].origin.y > slots[9].origin.y, "\(style.name)")
        }
    }

    @Test func classicIsFreeAndTheRestArePremium() {
        #expect(!BookcaseStyle.classic.isPremium)
        #expect(BookcaseStyle.allCases.filter(\.isPremium).count == BookcaseStyle.allCases.count - 1)
        #expect(RoomTheme.default.style == .classic)
    }
}
