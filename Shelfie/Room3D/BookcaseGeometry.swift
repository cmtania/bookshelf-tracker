import Foundation
import simd

/// Dimensions of the procedural bookcase, in metres. The case stands on the floor (y = 0)
/// against the back wall (z = 0), centred on x = 0, facing +z towards the camera.
/// Compartments are numbered in reading order: 0 1 / 2 3 / ... / 8 9 (top row first).
struct BookcaseGeometry {
    static let columns = 2
    static let rows = 5
    static let compartmentCount = columns * rows

    let width: Float = 1.6
    let height: Float = 2.0
    let depth: Float = 0.32
    let board: Float = 0.025
    let plinth: Float = 0.06
    /// Gap between the wall and the back panel.
    let backZ: Float = 0.02

    var frontZ: Float { backZ + depth }
    var innerWidth: Float { (width - 3 * board) / 2 }
    var rowHeight: Float { (height - plinth - 2 * board - Float(Self.rows - 1) * board) / Float(Self.rows) }
    /// Top of the bottom board.
    var floorY: Float { plinth + board }
    /// Compartment-local z of the case's front edge (origin sits just in front of the back panel).
    var localFrontZ: Float { depth - 0.01 }

    func row(of index: Int) -> Int { index / Self.columns }
    func column(of index: Int) -> Int { index % Self.columns }

    /// Bottom-left-back corner of the compartment's interior.
    func origin(of index: Int) -> SIMD3<Float> {
        let x = -width / 2 + board + Float(column(of: index)) * (innerWidth + board)
        let y = floorY + Float(Self.rows - 1 - row(of: index)) * (rowHeight + board)
        return SIMD3(x, y, backZ + 0.01)
    }

    /// Centre of the compartment's open front.
    func frontCenter(of index: Int) -> SIMD3<Float> {
        let o = origin(of: index)
        return SIMD3(o.x + innerWidth / 2, o.y + rowHeight / 2, frontZ)
    }

    /// y of the centre of the shelf board below row `row` (row 4's board is the bottom board).
    func boardCenterY(belowRow row: Int) -> Float {
        floorY + Float(Self.rows - 1 - row) * (rowHeight + board) - board / 2
    }
}

/// Book size from its page count; height and depth vary a little per book but stay stable.
struct BookDimensions: Equatable {
    var thickness: Float
    var height: Float
    var depth: Float

    init(pages: Int, id: UUID) {
        let bytes = id.uuid
        // ~0.1 mm per page plus the covers, clamped so pamphlets and doorstops both look sane.
        thickness = min(0.075, max(0.012, Float(max(pages, 1)) * 0.0001 + 0.004))
        height = 0.19 + Float(bytes.0 % 7) * 0.01
        depth = 0.14 + Float(bytes.1 % 4) * 0.012
    }
}
