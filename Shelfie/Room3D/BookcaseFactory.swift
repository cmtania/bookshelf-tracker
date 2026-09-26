import Foundation
import RealityKit
import UIKit

/// Builds the bookcase frame (rebuilt when the theme changes), and each compartment
/// (tap target, label, books) on every shelf change.
@MainActor
enum BookcaseFactory {
    struct CompartmentBuild {
        let entity: Entity
        let books: [UUID: Entity]
    }

    static func makeFrame(_ g: BookcaseGeometry, paint preset: RoomTheme.Preset) -> Entity {
        let frame = Entity()
        frame.name = "bookcase"
        let paintColor = UIColor(hex: preset.hex)
        let paint = RoomFactory.material(color: paintColor, finish: preset.finish)
        // The back panel sits in shadow, so it's a touch darker than the frame.
        let backPaint = RoomFactory.material(color: paintColor.adjustingBrightness(by: 0.93), roughness: 0.85)

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

        let layout = CompartmentLayout(compartment, geometry: g)
        var books: [UUID: Entity] = [:]
        let front = g.localFrontZ - 0.012
        for entry in layout.entries {
            let book = entry.book
            let d = entry.dimensions
            let bookEntity = BookEntityFactory.make(book, dimensions: d)
            let protrude: Float = book.status == .reading ? 0.03 : 0
            let z = front - d.depth / 2 + protrude
            if entry.placement.lying {
                // Rotated 90° about z: thickness becomes vertical, and the spine text reads left to right.
                bookEntity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
                bookEntity.position = [layout.centerX(of: entry), layout.bottomY(of: entry) + d.thickness / 2, z]
            } else {
                bookEntity.position = [layout.centerX(of: entry), d.height / 2, z]
            }
            entity.addChild(bookEntity)
            books[book.id] = bookEntity
        }

        entity.addChild(makePlate(compartment, hiddenCount: layout.hiddenCount, geometry: g))
        return CompartmentBuild(entity: entity, books: books)
    }

    /// Label size, shared with the share image. Big enough to read from the overview.
    nonisolated static let plateWidth: Float = 0.30
    nonisolated static let plateHeight: Float = 0.065

    /// Label on the front of the shelf board under the compartment. Its top lines up with the
    /// top of the board and it hangs down, so it never covers the books standing on the board.
    private static func makePlate(_ compartment: CompartmentSnapshot, hiddenCount: Int, geometry g: BookcaseGeometry) -> Entity {
        let width = plateWidth
        let height = plateHeight
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
        let plate = ModelEntity(mesh: .generatePlane(width: width, height: height, cornerRadius: 0.008), materials: [material])
        plate.name = "plate:\(compartment.index)"
        plate.position = [g.innerWidth / 2, -height / 2, g.localFrontZ + 0.002]
        plate.components.set(CollisionComponent(shapes: [.generateBox(width: width, height: height, depth: 0.004)]))
        plate.components.set(InputTargetComponent())
        return plate
    }
}
