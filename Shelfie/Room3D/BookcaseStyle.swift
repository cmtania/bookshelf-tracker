import Foundation
import simd

/// The shape of the bookcase. Classic is free; the others are part of Shelfie Pro.
/// Every style has exactly 10 compartments (one per category) in reading order, so categories,
/// labels, zooming, the book fly-out and the share image work the same for all of them.
enum BookcaseStyle: String, CaseIterable, Identifiable {
    case classic, pocket, floating, industrial, cubes, gallery, tree

    var id: String { rawValue }

    var name: String {
        switch self {
        case .classic: "Classic cabinet"
        case .pocket: "Pocket niches"
        case .floating: "Floating zigzag"
        case .industrial: "Industrial"
        case .cubes: "Cube wall"
        case .gallery: "Gallery boxes"
        case .tree: "Tree"
        }
    }

    var isPremium: Bool { self != .classic }

    var layout: BookcaseLayout { BookcaseLayouts.layout(for: self) }
}

/// One compartment's usable space for books, in world metres.
struct CompartmentSlot: Equatable {
    /// Bottom-left-back corner of the space where books stand.
    var origin: SIMD3<Float>
    var width: Float
    var height: Float
    /// Distance from `origin.z` to the front edge (where the label goes).
    var depth: Float

    var frontCenter: SIMD3<Float> {
        SIMD3(origin.x + width / 2, origin.y + height / 2, origin.z + depth)
    }
}

/// One solid box of the bookcase (or of the wall, for Pocket niches).
struct FramePiece {
    enum Role {
        /// The bookcase colour and finish from the theme.
        case paint
        /// A darker, matte version of the bookcase colour: back panels and plinths.
        case paintShade
        /// Black metal (Industrial posts).
        case metal
        /// The wall colour, with its plaster texture (Pocket niches' thick wall).
        case wall
        /// A darker wall colour for the inside of a niche.
        case wallShade
    }

    var center: SIMD3<Float>
    var size: SIMD3<Float>
    /// Rotation about the z axis, in radians (counter-clockwise, seen from the front).
    var angle: Float = 0
    var role: Role
}

struct BookcaseLayout {
    var slots: [CompartmentSlot]
    var pieces: [FramePiece]
    /// The area the camera frames and the share image shows (front view, metres).
    var minX: Float
    var maxX: Float
    var minY: Float
    var maxY: Float
    /// The front of the bookcase (camera distance is measured from here).
    var frontZ: Float

    var width: Float { maxX - minX }
    var height: Float { maxY - minY }
    var center: SIMD3<Float> { SIMD3((minX + maxX) / 2, (minY + maxY) / 2, frontZ) }

    /// Where the back wall's surface is at the ceiling: 0, or the front of a built-out wall that
    /// reaches the ceiling (Pocket niches), so the ceiling's moulding sits on it, not inside it.
    var wallFrontAtCeiling: Float {
        pieces
            // The room is 3.2 m tall (RoomFactory).
            .filter { $0.role == .wall && $0.center.y + $0.size.y / 2 >= 3.19 }
            .map { $0.center.z + $0.size.z / 2 }
            .max() ?? 0
    }
}

enum BookcaseLayouts {
    static func layout(for style: BookcaseStyle) -> BookcaseLayout {
        switch style {
        case .classic: classic()
        case .pocket: pocket()
        case .floating: floating()
        case .industrial: industrial()
        case .cubes: cubes()
        case .gallery: gallery()
        case .tree: tree()
        }
    }

    /// A box from its bottom-left-back corner and size.
    private static func box(_ x: Float, _ y: Float, _ z: Float, _ w: Float, _ h: Float, _ d: Float, _ role: FramePiece.Role) -> FramePiece {
        FramePiece(center: SIMD3(x + w / 2, y + h / 2, z + d / 2), size: SIMD3(w, h, d), role: role)
    }

    // MARK: Classic: the original 2 x 5 cabinet (free)

    static func classic() -> BookcaseLayout {
        let g = BookcaseGeometry()
        var pieces: [FramePiece] = []
        let z = g.backZ
        let innerSpan = g.width - 2 * g.board
        let left = -g.width / 2
        pieces.append(box(left, 0, z, g.board, g.height, g.depth, .paint))
        pieces.append(box(g.width / 2 - g.board, 0, z, g.board, g.height, g.depth, .paint))
        pieces.append(box(left, g.height - g.board, z, g.width, g.board, g.depth, .paint))
        pieces.append(box(left + g.board, g.plinth, z, innerSpan, g.board, g.depth, .paint))
        pieces.append(box(left + g.board, 0, g.frontZ - 0.02, innerSpan, g.plinth, 0.02, .paintShade))
        let dividerHeight = g.height - g.plinth - 2 * g.board
        pieces.append(box(-g.board / 2, g.plinth + g.board, z, g.board, dividerHeight, g.depth - 0.005, .paint))
        for row in 0..<(BookcaseGeometry.rows - 1) {
            pieces.append(box(left + g.board, g.boardCenterY(belowRow: row) - g.board / 2, z, innerSpan, g.board, g.depth - 0.005, .paint))
        }
        pieces.append(box(left, 0, z, g.width, g.height, 0.01, .paintShade))

        let slots = (0..<BookcaseGeometry.compartmentCount).map { index in
            CompartmentSlot(origin: g.origin(of: index), width: g.innerWidth, height: g.rowHeight, depth: g.localFrontZ)
        }
        return BookcaseLayout(slots: slots, pieces: pieces, minX: left, maxX: -left, minY: 0, maxY: g.height, frontZ: g.frontZ)
    }

    // MARK: Pocket niches: carved into a thick wall

    /// The whole back wall becomes a 30 cm thick slab (wall colour and plaster) with ten niches
    /// carved into it. Each niche has a darker back and a thin liner shelf in the bookcase colour.
    static func pocket() -> BookcaseLayout {
        let depth: Float = 0.30
        let backThickness: Float = 0.04
        let nicheWidth: Float = 0.72
        let nicheHeight: Float = 0.34
        let gapX: Float = 0.12
        let gapY: Float = 0.08
        let bottom: Float = 0.42
        let totalWidth = 2 * nicheWidth + gapX
        let x0 = -totalWidth / 2
        // The room's back wall is 5 m wide and 3.2 m tall (RoomFactory).
        let wallHalfWidth: Float = 2.5
        let wallHeight: Float = 3.2

        let niches: [(x: Float, y: Float)] = (0..<10).map { index in
            let row = index / 2
            let column = index % 2
            return (x0 + Float(column) * (nicheWidth + gapX), bottom + Float(4 - row) * (nicheHeight + gapY))
        }

        // Slab = the wall area minus the niches, split into boxes on the grid of niche edges.
        var xs = Set<Float>([-wallHalfWidth, wallHalfWidth])
        var ys = Set<Float>([0, wallHeight])
        for niche in niches {
            xs.insert(niche.x); xs.insert(niche.x + nicheWidth)
            ys.insert(niche.y); ys.insert(niche.y + nicheHeight)
        }
        let sortedX = xs.sorted()
        let sortedY = ys.sorted()
        func isNiche(_ x: Float, _ y: Float) -> Bool {
            niches.contains { x > $0.x && x < $0.x + nicheWidth && y > $0.y && y < $0.y + nicheHeight }
        }
        var pieces: [FramePiece] = []
        for j in 0..<(sortedY.count - 1) {
            let y = sortedY[j]
            let h = sortedY[j + 1] - y
            var runStart: Float?
            for i in 0..<(sortedX.count - 1) {
                let midX = (sortedX[i] + sortedX[i + 1]) / 2
                let solid = !isNiche(midX, y + h / 2)
                if solid, runStart == nil { runStart = sortedX[i] }
                if !solid, let start = runStart {
                    pieces.append(box(start, y, 0, sortedX[i] - start, h, depth, .wall))
                    runStart = nil
                }
            }
            if let start = runStart {
                pieces.append(box(start, y, 0, sortedX.last! - start, h, depth, .wall))
            }
        }
        for niche in niches {
            pieces.append(box(niche.x, niche.y, 0, nicheWidth, nicheHeight, backThickness, .wallShade))
            pieces.append(box(niche.x, niche.y, backThickness, nicheWidth, 0.015, depth - backThickness, .paint))
        }
        // Skirting along the front of the thick wall.
        pieces.append(box(-wallHalfWidth, 0, depth, 2 * wallHalfWidth, 0.08, 0.012, .wall))

        let slots = niches.map { niche in
            CompartmentSlot(
                origin: SIMD3(niche.x + 0.005, niche.y + 0.015, backThickness),
                width: nicheWidth - 0.01,
                height: nicheHeight - 0.015,
                depth: depth - backThickness
            )
        }
        let top = bottom + 5 * nicheHeight + 4 * gapY
        return BookcaseLayout(slots: slots, pieces: pieces, minX: x0 - 0.15, maxX: -x0 + 0.15, minY: bottom - 0.14, maxY: top + 0.12, frontZ: depth)
    }

    // MARK: Floating zigzag: planks joined by alternating side supports

    static func floating() -> BookcaseLayout {
        let width: Float = 1.5
        let thickness: Float = 0.04
        let depth: Float = 0.25
        let rowHeight: Float = 0.40
        let floors: [Float] = (0..<5).map { row in 0.34 + Float(4 - row) * (rowHeight + thickness) } // row 0 = top
        let left = -width / 2
        var pieces: [FramePiece] = []
        for floor in floors {
            pieces.append(box(left, floor - thickness, 0, width, thickness, depth, .paint))
        }
        let capTop = floors[0] + rowHeight + thickness
        pieces.append(box(left, capTop - thickness, 0, width, thickness, depth, .paint))

        var slots: [CompartmentSlot] = []
        for (row, floor) in floors.enumerated() {
            // The support alternates sides, making the zigzag.
            let supportOnRight = row % 2 == 0
            let supportX = supportOnRight ? width / 2 - thickness : left
            pieces.append(box(supportX, floor, 0, thickness, rowHeight, depth, .paint))
            let leftInset: Float = supportOnRight ? 0.02 : thickness + 0.02
            let rightInset: Float = supportOnRight ? thickness + 0.02 : 0.02
            slots.append(CompartmentSlot(origin: SIMD3(left + leftInset, floor, 0), width: width / 2 - leftInset - 0.01, height: rowHeight, depth: depth))
            slots.append(CompartmentSlot(origin: SIMD3(0.01, floor, 0), width: width / 2 - rightInset - 0.01, height: rowHeight, depth: depth))
        }
        return BookcaseLayout(slots: slots, pieces: pieces, minX: left - 0.1, maxX: -left + 0.1, minY: floors[4] - 0.15, maxY: capTop + 0.08, frontZ: depth)
    }

    // MARK: Industrial: wood shelves on black metal posts, open back

    static func industrial() -> BookcaseLayout {
        let width: Float = 1.6
        let depth: Float = 0.32
        let shelf: Float = 0.03
        let post: Float = 0.035
        let spacing: Float = 0.39
        let base: Float = 0.08
        let left = -width / 2
        var pieces: [FramePiece] = []
        for level in 0...5 {
            pieces.append(box(left, base + Float(level) * spacing, 0, width, shelf, depth, .paint))
        }
        let postHeight = base + 5 * spacing + shelf + 0.03
        for x in [left, -post / 2, width / 2 - post] {
            pieces.append(box(x, 0, depth - post, post, postHeight, post, .metal))
            pieces.append(box(x, 0, 0, post, postHeight, post, .metal))
            // Side rail joining front and back posts at the top.
            pieces.append(box(x, postHeight - post, post, post, post, depth - 2 * post, .metal))
        }
        let slots = (0..<10).map { index -> CompartmentSlot in
            let row = index / 2
            let column = index % 2
            let floor = base + shelf + Float(4 - row) * spacing
            let x = column == 0 ? left + post + 0.01 : post / 2 + 0.01
            return CompartmentSlot(origin: SIMD3(x, floor, 0.01), width: width / 2 - 1.5 * post - 0.02, height: spacing - shelf, depth: depth - 0.01)
        }
        return BookcaseLayout(slots: slots, pieces: pieces, minX: left, maxX: -left, minY: 0, maxY: postHeight, frontZ: depth)
    }

    // MARK: Cube wall and Gallery boxes: separate boxes hung on the wall

    private static func wallBox(_ x: Float, _ y: Float, _ w: Float, _ h: Float, depth: Float, board: Float, into pieces: inout [FramePiece]) -> CompartmentSlot {
        pieces.append(box(x, y, 0, w, board, depth, .paint))                       // bottom
        pieces.append(box(x, y + h - board, 0, w, board, depth, .paint))           // top
        pieces.append(box(x, y + board, 0, board, h - 2 * board, depth, .paint))   // left
        pieces.append(box(x + w - board, y + board, 0, board, h - 2 * board, depth, .paint)) // right
        pieces.append(box(x + board, y + board, 0, w - 2 * board, h - 2 * board, 0.01, .paintShade)) // back
        return CompartmentSlot(origin: SIMD3(x + board, y + board, 0.01), width: w - 2 * board, height: h - 2 * board, depth: depth - 0.01)
    }

    static func cubes() -> BookcaseLayout {
        let boxWidth: Float = 0.62
        let boxHeight: Float = 0.40
        let gap: Float = 0.08
        let depth: Float = 0.30
        let bottom: Float = 0.35
        let x0 = -(2 * boxWidth + gap) / 2
        var pieces: [FramePiece] = []
        let slots = (0..<10).map { index -> CompartmentSlot in
            let row = index / 2
            let column = index % 2
            let x = x0 + Float(column) * (boxWidth + gap)
            let y = bottom + Float(4 - row) * (boxHeight + gap)
            return wallBox(x, y, boxWidth, boxHeight, depth: depth, board: 0.02, into: &pieces)
        }
        let top = bottom + 5 * boxHeight + 4 * gap
        return BookcaseLayout(slots: slots, pieces: pieces, minX: x0 - 0.1, maxX: -x0 + 0.1, minY: bottom - 0.1, maxY: top + 0.1, frontZ: depth)
    }

    /// Boxes of different sizes in a collage, five rows from the top.
    static func gallery() -> BookcaseLayout {
        let depth: Float = 0.30
        let gap: Float = 0.05
        // (bottom y, height, x offset of the row, box widths left to right)
        let rows: [(y: Float, h: Float, offset: Float, widths: [Float])] = [
            (2.05, 0.42, -0.05, [0.55, 1.00]),
            (1.58, 0.42, 0.00, [0.40, 0.75, 0.40]),
            (1.01, 0.52, 0.05, [0.55, 0.95]),
            (0.54, 0.42, -0.03, [0.80, 0.75]),
            (0.07, 0.42, 0.10, [1.10]),
        ]
        var pieces: [FramePiece] = []
        var slots: [CompartmentSlot] = []
        var minX: Float = 0
        var maxX: Float = 0
        for row in rows {
            let total = row.widths.reduce(0, +) + gap * Float(row.widths.count - 1)
            var x = -total / 2 + row.offset
            minX = min(minX, x)
            for w in row.widths {
                slots.append(wallBox(x, row.y, w, row.h, depth: depth, board: 0.025, into: &pieces))
                x += w + gap
            }
            maxX = max(maxX, x - gap)
        }
        return BookcaseLayout(slots: slots, pieces: pieces, minX: minX - 0.1, maxX: maxX + 0.1, minY: 0, maxY: 2.05 + 0.42 + 0.1, frontZ: depth)
    }

    // MARK: Tree: a trunk with branch shelves

    static func tree() -> BookcaseLayout {
        let depth: Float = 0.25
        let trunkHalf: Float = 0.06
        let plank: Float = 0.04
        let branch: Float = 0.035
        var pieces: [FramePiece] = []
        pieces.append(box(-trunkHalf, 0, 0, 2 * trunkHalf, 2.55, depth, .paint))
        pieces.append(box(-0.12, 0, 0, 0.24, 0.12, depth, .paint)) // flared base

        // Crown: two short branches from the top of the trunk.
        pieces.append(FramePiece(center: SIMD3(-0.13, 2.66, depth / 2), size: SIMD3(branch, 0.36, depth), angle: 0.6, role: .paint))
        pieces.append(FramePiece(center: SIMD3(0.13, 2.66, depth / 2), size: SIMD3(branch, 0.36, depth), angle: -0.6, role: .paint))

        // Branch shelves. Left and right sides are staggered by 18 cm.
        let leftFloors: [Float] = [2.25, 1.80, 1.35, 0.90, 0.45]
        let leftLengths: [Float] = [0.55, 0.65, 0.70, 0.65, 0.60]
        let rightLengths: [Float] = [0.60, 0.70, 0.65, 0.70, 0.55]
        var slots: [CompartmentSlot] = []
        for row in 0..<5 {
            for side: Float in [-1, 1] {
                let floor = side < 0 ? leftFloors[row] : leftFloors[row] - 0.18
                let length = side < 0 ? leftLengths[row] : rightLengths[row]
                let innerX = side * trunkHalf
                let outerX = side * (trunkHalf + length)
                // The shelf itself.
                pieces.append(box(min(innerX, outerX), floor - plank, 0, length, plank, depth, .paint))
                // Upturned tip at the outer end, leaning outwards.
                pieces.append(FramePiece(center: SIMD3(outerX - side * 0.02, floor + 0.08, depth / 2), size: SIMD3(branch, 0.20, depth), angle: -side * 0.35, role: .paint))
                // Short diagonal brace from the trunk up to the shelf. It stays within 14 cm under the
                // shelf, above the tallest books on the branch below (whose space ends 9 cm under it).
                let from = SIMD2<Float>(innerX, floor - 0.14)
                let to = SIMD2<Float>(side * (trunkHalf + length * 0.45), floor - plank)
                let mid = (from + to) / 2
                let delta = to - from
                pieces.append(FramePiece(center: SIMD3(mid.x, mid.y, depth / 2), size: SIMD3(simd_length(delta), branch, depth), angle: atan2(delta.y, delta.x), role: .paint))

                let slotX = side < 0 ? outerX + 0.04 : innerX + 0.02
                slots.append(CompartmentSlot(origin: SIMD3(slotX, floor, 0), width: length - 0.06, height: 0.36, depth: depth))
            }
        }
        return BookcaseLayout(slots: slots, pieces: pieces, minX: -0.9, maxX: 0.9, minY: 0, maxY: 2.9, frontZ: depth)
    }
}
