import Foundation
import RealityKit
import UIKit

/// Builds the bookcase frame from the style's pieces (rebuilt when the theme changes), and each
/// compartment (tap target, label, books) from its slot on every shelf change.
@MainActor
enum BookcaseFactory {
    struct CompartmentBuild {
        let entity: Entity
        let books: [UUID: Entity]
    }

    static func makeFrame(_ layout: BookcaseLayout, theme: RoomTheme) -> Entity {
        let frame = Entity()
        frame.name = "bookcase"
        let paintColor = UIColor(hex: theme.shelf.hex)
        let paint = RoomFactory.material(color: paintColor, finish: theme.shelf.finish)
        // Back panels and plinths sit in shadow, so they're a touch darker and matte.
        let paintShade = RoomFactory.material(color: paintColor.adjustingBrightness(by: 0.93), roughness: 0.85)
        var metal = RoomFactory.material(hex: "#1E1F22", roughness: 0.45)
        metal.metallic = .init(floatLiteral: 0.6)
        let wall = RoomFactory.wallMaterial(hex: theme.wall.hex)
        let wallShade = RoomFactory.material(color: UIColor(hex: theme.wall.hex).adjustingBrightness(by: 0.84), roughness: 0.95)

        for piece in layout.pieces {
            let material: PhysicallyBasedMaterial
            switch piece.role {
            case .paint: material = paint
            case .paintShade: material = paintShade
            case .metal: material = metal
            case .wall: material = wall
            case .wallShade: material = wallShade
            }
            let entity = ModelEntity(
                mesh: .generateBox(width: piece.size.x, height: piece.size.y, depth: piece.size.z),
                materials: [material]
            )
            entity.position = piece.center
            if piece.angle != 0 {
                entity.orientation = simd_quatf(angle: piece.angle, axis: [0, 0, 1])
            }
            frame.addChild(entity)
        }
        return frame
    }

    static func makeCompartment(_ compartment: CompartmentSnapshot, slot: CompartmentSlot) -> CompartmentBuild {
        let entity = Entity()
        entity.name = "compartment:\(compartment.index)"
        entity.position = slot.origin

        // Tap target across the back of the compartment; books in front of it are hit first.
        let backShape = ShapeResource.generateBox(width: slot.width, height: slot.height, depth: 0.01)
            .offsetBy(translation: [slot.width / 2, slot.height / 2, 0.005])
        entity.components.set(CollisionComponent(shapes: [backShape]))
        entity.components.set(InputTargetComponent())

        let layout = CompartmentLayout(compartment, slot: slot)
        var books: [UUID: Entity] = [:]
        let front = slot.depth - 0.012
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

        entity.addChild(makePlate(compartment, hiddenCount: layout.hiddenCount, slot: slot))
        return CompartmentBuild(entity: entity, books: books)
    }

    /// Label size, shared with the share image. Big enough to read from the overview.
    nonisolated static let plateWidth: Float = 0.30
    nonisolated static let plateHeight: Float = 0.065

    /// Label width for a compartment: the standard width, narrower for small boxes.
    nonisolated static func labelWidth(for slot: CompartmentSlot) -> Float {
        min(plateWidth, slot.width - 0.02)
    }

    /// Label on the front edge under the compartment. Its top lines up with the compartment's
    /// floor and it hangs down, so it never covers the books standing there.
    private static func makePlate(_ compartment: CompartmentSnapshot, hiddenCount: Int, slot: CompartmentSlot) -> Entity {
        let width = labelWidth(for: slot)
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
        plate.position = [slot.width / 2, -height / 2, slot.depth + 0.002]
        plate.components.set(CollisionComponent(shapes: [.generateBox(width: width, height: height, depth: 0.004)]))
        plate.components.set(InputTargetComponent())
        return plate
    }
}
