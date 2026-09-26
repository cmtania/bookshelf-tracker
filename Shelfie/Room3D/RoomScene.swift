import RealityKit
import SwiftUI

/// Owns the RealityKit scene: room, bookcase, books and the camera.
/// Two camera poses: overview of the whole bookcase, and close-up on one compartment.
@MainActor
final class RoomScene {
    struct Hit {
        var compartment: Int?
        var bookID: UUID?
        var isPlate = false
    }

    let root = Entity()
    var reduceMotion = false
    private(set) var focusedCompartment: Int?

    private let camera = PerspectiveCamera()
    private let shelfRoot = Entity()
    private let geometry = BookcaseGeometry()
    private var isBuilt = false
    private var viewAspect: Float = 0.46
    private var bookEntities: [UUID: Entity] = [:]
    private var pulledOut: (entity: Entity, rest: Transform)?

    init() {
        camera.camera.fieldOfViewInDegrees = 55
        root.addChild(camera)
        root.addChild(shelfRoot)
    }

    // MARK: Building

    func update(_ snapshot: ShelfSnapshot) {
        buildStaticIfNeeded()
        pulledOut = nil
        bookEntities.removeAll()
        for child in Array(shelfRoot.children) {
            child.removeFromParent()
        }
        for compartment in snapshot.compartments {
            let build = BookcaseFactory.makeCompartment(compartment, geometry: geometry)
            shelfRoot.addChild(build.entity)
            bookEntities.merge(build.books) { first, _ in first }
        }
    }

    private func buildStaticIfNeeded() {
        guard !isBuilt else { return }
        isBuilt = true
        root.addChild(RoomFactory.makeRoom())
        root.addChild(BookcaseFactory.makeFrame(geometry))
        root.addChild(RoomFactory.makeLights())
        applyCamera(animated: false)
    }

    // MARK: Camera

    func setViewSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let aspect = Float(size.width / size.height)
        guard abs(aspect - viewAspect) > 0.001 else { return }
        viewAspect = aspect
        applyCamera(animated: false)
    }

    func focus(compartment: Int?) {
        pushBack()
        focusedCompartment = compartment
        applyCamera(animated: !reduceMotion)
    }

    private func applyCamera(animated: Bool) {
        let target = cameraTransform()
        if animated {
            camera.move(to: target, relativeTo: nil, duration: 0.6, timingFunction: .easeInOut)
        } else {
            camera.transform = target
        }
    }

    /// Pulls the camera back until the target fits both across and between the top bar and tab bar.
    private func cameraTransform() -> Transform {
        let fov = camera.camera.fieldOfViewInDegrees * .pi / 180
        let verticalTan = tan(fov / 2)
        let horizontalTan = verticalTan * viewAspect
        // Share of the screen height left after the top bar, chips and the tab bar.
        let usableHeight: Float = 0.72

        let center: SIMD3<Float>
        let halfWidth: Float
        let halfHeight: Float
        if let index = focusedCompartment {
            center = geometry.frontCenter(of: index)
            halfWidth = geometry.innerWidth / 2 + 0.06
            halfHeight = geometry.rowHeight / 2 + 0.08
        } else {
            center = [0, geometry.height / 2, geometry.frontZ]
            halfWidth = geometry.width / 2 + 0.12
            halfHeight = geometry.height / 2 + 0.1
        }
        let distance = max(halfWidth / horizontalTan, halfHeight / (verticalTan * usableHeight))

        var transform = Transform()
        if focusedCompartment == nil {
            // A slight angle on the overview, so the case reads as 3D rather than a flat picture.
            let sideOffset = distance * 0.12
            transform.translation = [center.x + sideOffset, center.y, center.z + distance]
            transform.rotation = simd_quatf(angle: atan2(sideOffset, distance), axis: [0, 1, 0])
        } else {
            transform.translation = [center.x, center.y, center.z + distance]
        }
        return transform
    }

    // MARK: Books

    func pullOut(bookID: UUID) {
        pushBack()
        guard let entity = bookEntities[bookID] else { return }
        let rest = entity.transform
        var out = rest
        out.translation.z += 0.12
        pulledOut = (entity, rest)
        if reduceMotion {
            entity.transform = out
        } else {
            entity.move(to: out, relativeTo: entity.parent, duration: 0.35, timingFunction: .easeInOut)
        }
    }

    func pushBack() {
        guard let pulled = pulledOut else { return }
        pulledOut = nil
        if reduceMotion {
            pulled.entity.transform = pulled.rest
        } else {
            pulled.entity.move(to: pulled.rest, relativeTo: pulled.entity.parent, duration: 0.3, timingFunction: .easeInOut)
        }
    }

    // MARK: Hit testing

    /// Walks up from the tapped entity to find which book / compartment / label it belongs to.
    static func resolve(_ entity: Entity) -> Hit {
        var hit = Hit()
        var current: Entity? = entity
        while let e = current {
            let name = e.name
            if name.hasPrefix("book:"), hit.bookID == nil {
                hit.bookID = UUID(uuidString: String(name.dropFirst("book:".count)))
            } else if name.hasPrefix("plate:") {
                hit.isPlate = true
            } else if name.hasPrefix("compartment:") {
                hit.compartment = Int(name.dropFirst("compartment:".count))
                break
            }
            current = e.parent
        }
        return hit
    }
}
