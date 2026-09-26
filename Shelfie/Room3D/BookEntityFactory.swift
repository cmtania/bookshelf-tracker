import RealityKit
import UIKit

/// A book is built like a real one: two cloth cover boards, a cream page block between them
/// and a cloth spine facing +z (towards the room). The front cover is the +x board.
/// Books being read get a red bookmark ribbon sticking out of the top.
@MainActor
enum BookEntityFactory {
    static let coverName = "cover"
    private static let board: Float = 0.0025

    static func make(_ book: BookSnapshot, dimensions d: BookDimensions) -> Entity {
        let root = Entity()
        root.name = "book:\(book.id.uuidString)"
        root.components.set(CollisionComponent(shapes: [.generateBox(width: d.thickness, height: d.height, depth: d.depth)]))
        root.components.set(InputTargetComponent())

        let cloth = RoomFactory.material(hex: book.spineColorHex, roughness: 0.55)
        let paper = RoomFactory.material(hex: "#F3EBD8", roughness: 0.95)

        // Page block, slightly smaller than the covers so the boards overhang it.
        let pages = ModelEntity(
            mesh: .generateBox(width: max(0.002, d.thickness - 2 * board), height: d.height - 0.006, depth: d.depth - 0.006),
            materials: [paper]
        )
        pages.position = [0, 0, -0.001]
        root.addChild(pages)

        // Front (+x) and back (-x) boards.
        for side: Float in [1, -1] {
            let cover = ModelEntity(
                mesh: .generateBox(width: board, height: d.height, depth: d.depth, cornerRadius: 0.0008),
                materials: [cloth]
            )
            cover.position = [side * (d.thickness / 2 - board / 2), 0, 0]
            root.addChild(cover)
        }

        // Spine strip joining the boards, with the title texture on top of it.
        let spineStrip = ModelEntity(mesh: .generateBox(width: d.thickness, height: d.height, depth: board), materials: [cloth])
        spineStrip.position = [0, 0, d.depth / 2 - board / 2]
        root.addChild(spineStrip)

        if let texture = TextureFactory.spine(
            title: book.title,
            author: book.author,
            colorHex: book.spineColorHex,
            width: d.thickness,
            height: d.height
        ) {
            var spineMaterial = RoomFactory.material(hex: "#FFFFFF", roughness: 0.55)
            spineMaterial.baseColor = .init(tint: .white, texture: .init(texture))
            let spine = ModelEntity(mesh: .generatePlane(width: d.thickness * 0.98, height: d.height * 0.98), materials: [spineMaterial])
            spine.position = [0, 0, d.depth / 2 + 0.0008]
            root.addChild(spine)
        }

        if book.status == .reading {
            let ribbon = ModelEntity(
                mesh: .generateBox(width: 0.006, height: 0.03, depth: 0.0015),
                materials: [RoomFactory.material(hex: "#C0392B", roughness: 0.6)]
            )
            ribbon.position = [0, d.height / 2 + 0.005, d.depth / 2 - 0.012]
            root.addChild(ribbon)
        }
        return root
    }

    /// Adds the printed front cover. Done lazily, only for the book being shown up close,
    /// so a full shelf doesn't render a cover texture for every book.
    static func addCoverIfNeeded(to entity: Entity, book: BookSnapshot, dimensions d: BookDimensions) {
        guard entity.findEntity(named: coverName) == nil,
              let texture = TextureFactory.cover(
                title: book.title,
                author: book.author,
                colorHex: book.spineColorHex,
                width: d.depth,
                height: d.height
              )
        else { return }
        var material = RoomFactory.material(hex: "#FFFFFF", roughness: 0.5)
        material.baseColor = .init(tint: .white, texture: .init(texture))
        let cover = ModelEntity(mesh: .generatePlane(width: d.depth * 0.985, height: d.height * 0.985), materials: [material])
        cover.name = coverName
        // Planes face +z; turn it to face +x, reading from the spine edge towards the fore-edge.
        cover.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
        cover.position = [d.thickness / 2 + 0.0006, 0, 0]
        entity.addChild(cover)
    }
}
