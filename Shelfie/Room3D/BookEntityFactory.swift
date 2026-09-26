import RealityKit
import UIKit

@MainActor
enum BookEntityFactory {
    /// A book is a coloured box with a textured spine plane on its front (+z) face.
    /// Books being read get a red bookmark ribbon sticking out of the top.
    static func make(_ book: BookSnapshot, dimensions d: BookDimensions) -> ModelEntity {
        let cloth = RoomFactory.material(hex: book.spineColorHex, roughness: 0.55)
        let body = ModelEntity(
            mesh: .generateBox(width: d.thickness, height: d.height, depth: d.depth, cornerRadius: 0.002),
            materials: [cloth]
        )
        body.name = "book:\(book.id.uuidString)"
        body.components.set(CollisionComponent(shapes: [.generateBox(width: d.thickness, height: d.height, depth: d.depth)]))
        body.components.set(InputTargetComponent())

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
            body.addChild(spine)
        }

        if book.status == .reading {
            let ribbon = ModelEntity(
                mesh: .generateBox(width: 0.006, height: 0.03, depth: 0.0015),
                materials: [RoomFactory.material(hex: "#C0392B", roughness: 0.6)]
            )
            ribbon.position = [0, d.height / 2 + 0.005, d.depth / 2 - 0.012]
            body.addChild(ribbon)
        }
        return body
    }
}
