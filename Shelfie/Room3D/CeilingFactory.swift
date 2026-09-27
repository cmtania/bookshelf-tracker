import RealityKit
import UIKit

/// A coffered ceiling instead of a flat plane:
/// - a stepped crown moulding where the walls meet the ceiling,
/// - a grid of beams with stepped edges, dividing the ceiling into 3 × 5 recessed panels,
/// - a round downlight with a metal trim in the middle of each panel.
/// Everything is in the wall colour, so it suits every room colour; the detail comes from the
/// shapes catching the light, with the panels a touch darker than the beams to read as recessed.
@MainActor
enum CeilingFactory {
    /// Crown moulding steps, bottom to top: (how far it sticks out from the wall, bottom y, top y).
    /// The gap between the bead and the first step leaves a thin shadow line.
    private static let crownSteps: [(projection: Float, bottom: Float, top: Float)] = [
        (0.020, 3.020, 3.040),
        (0.035, 3.060, 3.100),
        (0.060, 3.100, 3.150),
        (0.090, 3.150, 3.200),
    ]

    /// Beam cross-section, bottom to top: (width, bottom y, top y). A narrow soffit bead, the beam,
    /// and a wide fillet where the beam meets the panel.
    private static let beamSteps: [(width: Float, bottom: Float, top: Float)] = [
        (0.10, 3.045, 3.060),
        (0.14, 3.060, 3.200),
        (0.22, 3.175, 3.200),
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

        // Recessed panels: the plaster ceiling, slightly darker than the trim.
        var panel = RoomFactory.material(color: wallColor, roughness: 0.95)
        if let plaster = TextureFactory.ceiling(hex: wallHex) {
            panel.baseColor = .init(tint: UIColor(white: 0.95, alpha: 1), texture: .init(plaster))
        }
        let plane = ModelEntity(mesh: .generatePlane(width: width, depth: depth - backWallZ), materials: [panel])
        plane.position = [0, height, backWallZ + (depth - backWallZ) / 2]
        plane.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        add(plane, to: ceiling)

        // Satin-painted trim for the moulding and beams.
        let trim = RoomFactory.material(color: wallColor.adjustingBrightness(by: 1.05), roughness: 0.55)

        // Crown moulding along the back wall and both side walls (the front of the room is open).
        for step in crownSteps {
            add(box(x: -halfWidth...halfWidth, y: step.bottom...step.top, z: backWallZ...(backWallZ + step.projection), trim), to: ceiling)
            add(box(x: -halfWidth...(-halfWidth + step.projection), y: step.bottom...step.top, z: backWallZ...depth, trim), to: ceiling)
            add(box(x: (halfWidth - step.projection)...halfWidth, y: step.bottom...step.top, z: backWallZ...depth, trim), to: ceiling)
        }

        // The panels are laid out inside the moulding; the beams run into the walls like real ones.
        let inset = crownSteps.last!.projection
        let innerMinX = -halfWidth + inset
        let innerWidth = width - 2 * inset
        let innerMinZ = backWallZ + inset
        let innerDepth = depth - innerMinZ
        let bayWidth = innerWidth / Float(columns)
        let bayDepth = innerDepth / Float(rows)

        for column in 1..<columns {
            let x = innerMinX + Float(column) * bayWidth
            for step in beamSteps {
                add(box(x: (x - step.width / 2)...(x + step.width / 2), y: step.bottom...step.top, z: backWallZ...depth, trim), to: ceiling)
            }
        }
        for row in 1..<rows {
            let z = innerMinZ + Float(row) * bayDepth
            for step in beamSteps {
                // 1 mm higher than the other beams, so the faces where they cross don't flicker.
                let y = (step.bottom + 0.001)...(step.top + 0.001)
                add(box(x: -halfWidth...halfWidth, y: y, z: (z - step.width / 2)...(z + step.width / 2), trim), to: ceiling)
            }
        }

        // A downlight in the middle of each panel: brushed metal ring and a glowing warm lens.
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
                let x = innerMinX + (Float(column) + 0.5) * bayWidth
                let z = innerMinZ + (Float(row) + 0.5) * bayDepth
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

    /// The sun shines from above, so without this the beams would cast stripes of shadow over the room.
    private static func add(_ entity: ModelEntity, to parent: Entity) {
        entity.components.set(DynamicLightShadowComponent(castsShadow: false))
        parent.addChild(entity)
    }
}
