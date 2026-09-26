import Foundation

/// Lays books out inside one compartment (all units in metres, compartment-local).
/// Upright books pack left to right. Want-to-read books, and any upright books that don't
/// fit, lie flat in a stack at the right end. Whatever doesn't fit in the stack is hidden
/// and counted, so the shelf can show "+N".
struct ShelfPacker {
    struct Item: Equatable {
        var id: UUID
        var thickness: Float
        var lieFlat: Bool
    }

    struct Placement: Equatable {
        var id: UUID
        /// Left edge of the book (upright) or of the stack area (lying).
        var x: Float
        /// Bottom of the book: 0 for upright books, the stack height below it for lying ones.
        var y: Float
        var lying: Bool
    }

    struct Result: Equatable {
        var placements: [Placement]
        var hiddenCount: Int
    }

    var innerWidth: Float
    var innerHeight: Float
    var gap: Float = 0.002
    /// Width reserved at the right end for the flat stack (longer than the tallest book).
    var stackFootprint: Float = 0.27
    var topClearance: Float = 0.02

    func pack(_ items: [Item]) -> Result {
        let upright = items.filter { !$0.lieFlat }
        var flat = items.filter { $0.lieFlat }

        let uprightWidth = upright.reduce(Float(0)) { $0 + $1.thickness + gap }
        let needsStack = !flat.isEmpty || uprightWidth > innerWidth
        let uprightLimit = needsStack ? innerWidth - stackFootprint : innerWidth

        var placements: [Placement] = []
        var overflow: [Item] = []
        var x: Float = 0
        for item in upright {
            if overflow.isEmpty, x + item.thickness <= uprightLimit {
                placements.append(Placement(id: item.id, x: x, y: 0, lying: false))
                x += item.thickness + gap
            } else {
                overflow.append(item)
            }
        }

        flat += overflow
        var hidden = 0
        var y: Float = 0
        let stackX = innerWidth - stackFootprint
        for item in flat {
            if y + item.thickness <= innerHeight - topClearance {
                placements.append(Placement(id: item.id, x: stackX, y: y, lying: true))
                y += item.thickness
            } else {
                hidden += 1
            }
        }
        return Result(placements: placements, hiddenCount: hidden)
    }
}
