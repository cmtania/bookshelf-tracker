import RealityKit
import UIKit

/// The ceiling instead of a flat plane:
/// - a two-step crown moulding where the walls meet the ceiling,
/// - a 3 × 5 grid of round downlights with a metal trim.
/// Everything is in the wall colour, so it suits every room colour; the detail comes from the
/// moulding catching the light, with the ceiling a touch darker than the trim so it stands out.
@MainActor
enum CeilingFactory {
    /// Crown moulding steps, bottom to top: (how far it sticks out from the wall, bottom y, top y).
    private static let crownSteps: [(projection: Float, bottom: Float, top: Float)] = [
        (0.040, 3.080, 3.140),
        (0.080, 3.140, 3.200),
    ]

    private static let columns = 3
    private static let rows = 5

    /// `backWallZ` is where the back wall's surface is: 0, or further forward when a design builds
    /// the wall out (Pocket niches), so the moulding sits on the wall instead of inside it.
    static func makeCeiling(wallHex: String, backWallZ: Float) -> Entity {
        let ceiling = Entity()
        ceiling.name = "ceiling"
        let width = RoomFactory.roomWidth
        let depth = RoomFactory.roomDepth
        let height = RoomFactory.roomHeight
        let halfWidth = width / 2
        let wallColor = UIColor(hex: wallHex)

        // The plaster ceiling, slightly darker than the trim.
        var plaster = RoomFactory.material(color: wallColor, roughness: 0.95)
        if let texture = TextureFactory.ceiling(hex: wallHex) {
            plaster.baseColor = .init(tint: UIColor(white: 0.95, alpha: 1), texture: .init(texture))
        }
        let plane = ModelEntity(mesh: .generatePlane(width: width, depth: depth - backWallZ), materials: [plaster])
        plane.position = [0, height, backWallZ + (depth - backWallZ) / 2]
        plane.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        add(plane, to: ceiling)

        // Satin-painted trim for the moulding.
        let trim = RoomFactory.material(color: wallColor.adjustingBrightness(by: 1.05), roughness: 0.55)

        // Crown moulding along the back wall and both side walls (the front of the room is open).
        for step in crownSteps {
            add(box(x: -halfWidth...halfWidth, y: step.bottom...step.top, z: backWallZ...(backWallZ + step.projection), trim), to: ceiling)
            add(box(x: -halfWidth...(-halfWidth + step.projection), y: step.bottom...step.top, z: backWallZ...depth, trim), to: ceiling)
            add(box(x: (halfWidth - step.projection)...halfWidth, y: step.bottom...step.top, z: backWallZ...depth, trim), to: ceiling)
        }

        // Downlights spread evenly over the ceiling inside the moulding: brushed metal ring and a
        // glowing warm lens.
        let inset = crownSteps.last!.projection
        let innerMinX = -halfWidth + inset
        let innerMinZ = backWallZ + inset
        let cellWidth = (width - 2 * inset) / Float(columns)
        let cellDepth = (depth - innerMinZ) / Float(rows)

        var ring = PhysicallyBasedMaterial()
        ring.baseColor = .init(tint: UIColor(white: 0.82, alpha: 1))
        // Half metallic (satin nickel), so the ring stays light even where little is reflected.
        ring.metallic = .init(floatLiteral: 0.5)
        ring.roughness = .init(floatLiteral: 0.4)
        let lens = UnlitMaterial(color: UIColor(red: 1, green: 0.96, blue: 0.86, alpha: 1))
        let ringMesh = MeshResource.generateCylinder(height: 0.012, radius: 0.075)
        let lensMesh = MeshResource.generateCylinder(height: 0.016, radius: 0.052)
        for column in 0..<columns {
            for row in 0..<rows {
                let x = innerMinX + (Float(column) + 0.5) * cellWidth
                let z = innerMinZ + (Float(row) + 0.5) * cellDepth
                let trimRing = ModelEntity(mesh: ringMesh, materials: [ring])
                trimRing.position = [x, height - 0.006, z]
                add(trimRing, to: ceiling)
                let glow = ModelEntity(mesh: lensMesh, materials: [lens])
                glow.position = [x, height - 0.008, z]
                add(glow, to: ceiling)
            }
        }

        return ceiling
    }

    private static func box(x: ClosedRange<Float>, y: ClosedRange<Float>, z: ClosedRange<Float>, _ material: PhysicallyBasedMaterial) -> ModelEntity {
        let size = SIMD3(x.upperBound - x.lowerBound, y.upperBound - y.lowerBound, z.upperBound - z.lowerBound)
        let entity = ModelEntity(mesh: .generateBox(size: size), materials: [material])
        entity.position = [(x.lowerBound + x.upperBound) / 2, (y.lowerBound + y.upperBound) / 2, (z.lowerBound + z.upperBound) / 2]
        return entity
    }

    /// The sun shines from above, so without this the moulding would cast shadows down the walls.
    private static func add(_ entity: ModelEntity, to parent: Entity) {
        entity.components.set(DynamicLightShadowComponent(castsShadow: false))
        parent.addChild(entity)
    }
}
