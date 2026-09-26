import Foundation
import RealityKit

/// Builds the bookcase frame once, and each compartment (tap target, label, books) on every shelf change.
@MainActor
enum BookcaseFactory {
    static let paintHex = "#F1EFEA"

    struct CompartmentBuild {
        let entity: Entity
        let books: [UUID: Entity]
    }

    static func makeFrame(_ g: BookcaseGeometry) -> Entity {
        let frame = Entity()
        frame.name = "bookcase"
        let paint = RoomFactory.material(hex: paintHex, roughness: 0.7)
        let backPaint = RoomFactory.material(hex: "#E6E3DC", roughness: 0.85)

        func board(_ width: Float, _ height: Float, _ depth: Float, _ position: SIMD3<Float>, _ material: PhysicallyBasedMaterial) {
            let entity = ModelEntity(mesh: .generateBox(width: width, height: height, depth: depth), materials: [material])
            entity.position = position
            frame.addChild(entity)
        }

        let z = g.backZ + g.depth / 2
        let innerSpan = g.width - 2 * g.board
        // Sides and top.
        board(g.board, g.height, g.depth, [-g.width / 2 + g.board / 2, g.height / 2, z], paint)
        board(g.board, g.height, g.depth, [g.width / 2 - g.board / 2, g.height / 2, z], paint)
        board(g.width, g.board, g.depth, [0, g.height - g.board / 2, z], paint)
        // Bottom board and plinth.
        board(innerSpan, g.board, g.depth, [0, g.plinth + g.board / 2, z], paint)
        board(innerSpan, g.plinth, 0.02, [0, g.plinth / 2, g.frontZ - 0.01], paint)
        // Middle divider.
        let dividerHeight = g.height - g.plinth - 2 * g.board
        board(g.board, dividerHeight, g.depth - 0.005, [0, g.plinth + g.board + dividerHeight / 2, z], paint)
        // Shelves between rows.
        for row in 0..<(BookcaseGeometry.rows - 1) {
            board(innerSpan, g.board, g.depth - 0.005, [0, g.boardCenterY(belowRow: row), z], paint)
        }
        // Back panel.
        board(g.width, g.height, 0.01, [0, g.height / 2, g.backZ + 0.005], backPaint)
        return frame
    }

    static func makeCompartment(_ compartment: CompartmentSnapshot, geometry g: BookcaseGeometry) -> CompartmentBuild {
        let entity = Entity()
        entity.name = "compartment:\(compartment.index)"
        entity.position = g.origin(of: compartment.index)

        // Tap target across the back of the compartment; books in front of it are hit first.
        let backShape = ShapeResource.generateBox(width: g.innerWidth, height: g.rowHeight, depth: 0.01)
            .offsetBy(translation: [g.innerWidth / 2, g.rowHeight / 2, 0.005])
        entity.components.set(CollisionComponent(shapes: [backShape]))
        entity.components.set(InputTargetComponent())

        let packer = ShelfPacker(innerWidth: g.innerWidth - 0.01, innerHeight: g.rowHeight)
        let dimensions = Dictionary(
            compartment.books.map { ($0.id, BookDimensions(pages: $0.totalPages, id: $0.id)) },
            uniquingKeysWith: { first, _ in first }
        )
        let byID = Dictionary(compartment.books.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let items = compartment.books.compactMap { book -> ShelfPacker.Item? in
            guard let d = dimensions[book.id] else { return nil }
            return ShelfPacker.Item(id: book.id, thickness: d.thickness, lieFlat: book.status == .wantToRead)
        }
        let layout = packer.pack(items)

        var books: [UUID: Entity] = [:]
        let inset: Float = 0.005
        let front = g.localFrontZ - 0.012
        for placement in layout.placements {
            guard let book = byID[placement.id], let d = dimensions[placement.id] else { continue }
            let bookEntity = BookEntityFactory.make(book, dimensions: d)
            let protrude: Float = book.status == .reading ? 0.03 : 0
            if placement.lying {
                // Rotated 90° about z: thickness becomes vertical, and the spine text reads left to right.
                bookEntity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
                bookEntity.position = [inset + placement.x + packer.stackFootprint / 2, placement.y + d.thickness / 2, front - d.depth / 2 + protrude]
            } else {
                bookEntity.position = [inset + placement.x + d.thickness / 2, d.height / 2, front - d.depth / 2 + protrude]
            }
            entity.addChild(bookEntity)
            books[book.id] = bookEntity
        }

        entity.addChild(makePlate(compartment, hiddenCount: layout.hiddenCount, geometry: g))
        return CompartmentBuild(entity: entity, books: books)
    }

    /// Label on the front of the shelf board under the compartment.
    private static func makePlate(_ compartment: CompartmentSnapshot, hiddenCount: Int, geometry g: BookcaseGeometry) -> Entity {
        let width: Float = 0.2
        let height: Float = 0.038
        let text: String
        if let name = compartment.name {
            text = hiddenCount > 0 ? "\(name) · +\(hiddenCount)" : name
        } else {
            text = "+ Add category"
        }
        var material = RoomFactory.material(hex: "#FFFFFF", roughness: 0.8)
        if let texture = TextureFactory.plate(text: text, isPlaceholder: compartment.isEmpty, width: width, height: height) {
            material.baseColor = .init(tint: .white, texture: .init(texture))
        }
        let plate = ModelEntity(mesh: .generatePlane(width: width, height: height, cornerRadius: 0.004), materials: [material])
        plate.name = "plate:\(compartment.index)"
        plate.position = [g.innerWidth / 2, -g.board / 2, g.localFrontZ + 0.002]
        plate.components.set(CollisionComponent(shapes: [.generateBox(width: width, height: height, depth: 0.004)]))
        plate.components.set(InputTargetComponent())
        return plate
    }
}
