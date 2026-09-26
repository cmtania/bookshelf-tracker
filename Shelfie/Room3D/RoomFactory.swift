import RealityKit
import UIKit

/// The room around the bookcase: walls, ceiling, wood floor and skirting, coloured by the theme.
/// The default theme is the white room with a light wood floor from the reference image.
@MainActor
enum RoomFactory {
    static let roomWidth: Float = 5
    static let roomDepth: Float = 7
    static let roomHeight: Float = 3.2

    static func makeRoom(theme: RoomTheme) -> Entity {
        let room = Entity()
        room.name = "room"
        let wallColor = UIColor(hex: theme.wallHex)
        let wall = material(color: wallColor, roughness: 0.95)
        let halfWidth = roomWidth / 2

        let back = ModelEntity(mesh: .generatePlane(width: roomWidth, height: roomHeight), materials: [wall])
        back.position = [0, roomHeight / 2, 0]
        room.addChild(back)

        // Planes face +z; turn the side walls to face into the room.
        let left = ModelEntity(mesh: .generatePlane(width: roomDepth, height: roomHeight), materials: [wall])
        left.position = [-halfWidth, roomHeight / 2, roomDepth / 2]
        left.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
        room.addChild(left)

        let right = ModelEntity(mesh: .generatePlane(width: roomDepth, height: roomHeight), materials: [wall])
        right.position = [halfWidth, roomHeight / 2, roomDepth / 2]
        right.orientation = simd_quatf(angle: -.pi / 2, axis: [0, 1, 0])
        room.addChild(right)

        let ceiling = ModelEntity(
            mesh: .generatePlane(width: roomWidth, depth: roomDepth),
            materials: [material(color: wallColor.adjustingBrightness(by: 1.04), roughness: 1)]
        )
        ceiling.position = [0, roomHeight, roomDepth / 2]
        ceiling.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        room.addChild(ceiling)

        var floorMaterial = material(hex: theme.floorHex, roughness: 0.6)
        if let wood = TextureFactory.woodFloor(baseHex: theme.floorHex) {
            floorMaterial.baseColor = .init(tint: .white, texture: .init(wood))
        }
        let floor = ModelEntity(mesh: .generatePlane(width: roomWidth, depth: roomDepth), materials: [floorMaterial])
        floor.position = [0, 0, roomDepth / 2]
        room.addChild(floor)

        let skirting = ModelEntity(
            mesh: .generateBox(width: roomWidth, height: 0.08, depth: 0.012),
            materials: [material(color: wallColor.adjustingBrightness(by: 1.06), roughness: 0.7)]
        )
        skirting.position = [0, 0.04, 0.006]
        room.addChild(skirting)

        return room
    }

    static func makeLights() -> Entity {
        let lights = Entity()
        lights.name = "lights"

        let sun = DirectionalLight()
        sun.light.color = .white
        sun.light.intensity = 1800
        sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 6, depthBias: 2)
        sun.look(at: [0, 0.8, 0], from: [1.5, 3.0, 3.0], relativeTo: nil)
        lights.addChild(sun)

        let fill = PointLight()
        fill.light.color = .white
        fill.light.intensity = 25_000
        fill.light.attenuationRadius = 8
        fill.position = [-0.8, 2.6, 2.4]
        lights.addChild(fill)

        return lights
    }

    static func material(hex: String, roughness: Float) -> PhysicallyBasedMaterial {
        material(color: UIColor(hex: hex), roughness: roughness)
    }

    static func material(color: UIColor, roughness: Float) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = .init(floatLiteral: 0)
        return material
    }
}
