import RealityKit
import SwiftUI

/// Owns the RealityKit scene: room, bookcase, books and the camera.
/// Two camera poses: overview of the whole bookcase, and close-up on one compartment.
/// A tapped book is "presented": it slides out, then flies up in front of the camera showing its cover.
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
    private var bookSnapshots: [UUID: BookSnapshot] = [:]
    /// Where the camera is (or is heading); presentation poses are placed relative to it.
    private var cameraTarget = Transform()

    /// The book currently lifted out of the shelf and shown up close.
    private struct Presented {
        var id: UUID
        var entity: Entity
        var rest: Transform
        var dimensions: BookDimensions
        var yaw: Float = 0
        var dragStartYaw: Float?
    }
    private var presented: Presented?
    private let dimmer = Entity()

    private var theme = RoomTheme.default
    private var roomEntity: Entity?
    private var frameEntity: Entity?

    init() {
        camera.camera.fieldOfViewInDegrees = 55
        root.addChild(camera)
        root.addChild(shelfRoot)
    }

    // MARK: Building

    func update(_ snapshot: ShelfSnapshot) {
        buildStaticIfNeeded()
        bookEntities.removeAll()
        bookSnapshots.removeAll()
        for child in Array(shelfRoot.children) {
            child.removeFromParent()
        }
        for compartment in snapshot.compartments {
            let build = BookcaseFactory.makeCompartment(compartment, geometry: geometry)
            shelfRoot.addChild(build.entity)
            bookEntities.merge(build.books) { first, _ in first }
            for book in compartment.books {
                bookSnapshots[book.id] = book
            }
        }
        // A rebuild (e.g. after logging a session changes the status) replaces every book entity.
        // Keep the presented book up close by moving its new entity straight to the pose.
        if let current = presented {
            if let entity = bookEntities[current.id], let book = bookSnapshots[current.id] {
                let dimensions = BookDimensions(pages: book.totalPages, id: book.id)
                presented = Presented(id: current.id, entity: entity, rest: entity.transform, dimensions: dimensions, yaw: current.yaw)
                BookEntityFactory.addCoverIfNeeded(to: entity, book: book, dimensions: dimensions)
                entity.setTransformMatrix(presentationTransform(dimensions, yaw: current.yaw).matrix, relativeTo: nil)
            } else {
                presented = nil
                dimmer.isEnabled = false
            }
        }
    }

    private func buildStaticIfNeeded() {
        guard !isBuilt else { return }
        isBuilt = true
        buildThemedParts()
        root.addChild(RoomFactory.makeLights())
        root.addChild(makeDimmer())
        applyCamera(animated: false)
    }

    /// Applies new room colours; only the room and the bookcase frame are rebuilt, the books stay.
    func setTheme(_ newTheme: RoomTheme) {
        guard newTheme != theme else { return }
        theme = newTheme
        if isBuilt { buildThemedParts() }
    }

    private func buildThemedParts() {
        roomEntity?.removeFromParent()
        frameEntity?.removeFromParent()
        let room = RoomFactory.makeRoom(theme: theme)
        let frame = BookcaseFactory.makeFrame(geometry, paint: theme.shelf)
        root.addChild(room)
        root.addChild(frame)
        roomEntity = room
        frameEntity = frame
    }

    /// A translucent dark plane placed between the room and the presented book.
    private func makeDimmer() -> Entity {
        var material = UnlitMaterial(color: .black)
        material.blending = .transparent(opacity: 0.45)
        let plane = ModelEntity(mesh: .generatePlane(width: 20, height: 20), materials: [material])
        dimmer.addChild(plane)
        dimmer.isEnabled = false
        return dimmer
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
        focusedCompartment = compartment
        applyCamera(animated: !reduceMotion)
    }

    /// While the room colors sheet covers the bottom half of the screen, the camera pulls back
    /// and tilts down to show the whole room (bookcase, walls and floor) in the top half.
    private(set) var isPreviewingRoom = false

    func setRoomPreview(_ previewing: Bool) {
        guard previewing != isPreviewingRoom else { return }
        isPreviewingRoom = previewing
        applyCamera(animated: !reduceMotion)
    }

    private func applyCamera(animated: Bool) {
        let target = cameraTransform()
        cameraTarget = target
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

        if isPreviewingRoom {
            return roomPreviewTransform(verticalTan: verticalTan, horizontalTan: horizontalTan)
        }

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

    /// Frames the bookcase plus a good margin of wall and floor in the **top half** of the screen.
    /// The top half spans tangents 0...verticalTan above the optical axis, so the camera tilts down by
    /// atan(verticalTan / 2): that puts the room's centre in the middle of the top half.
    private func roomPreviewTransform(verticalTan: Float, horizontalTan: Float) -> Transform {
        let center = SIMD3<Float>(0, geometry.height / 2, geometry.frontZ)
        // Half-sizes of what should be visible: the bookcase with wall on both sides, and floor in front.
        let halfWidth = geometry.width / 2 + 0.7
        let halfHeight = geometry.height / 2 + 0.45
        let distance = max(halfWidth / horizontalTan, halfHeight / (verticalTan / 2))
        // Stay inside the room (it's 7 m deep), so the camera never sees past the walls' edges.
        let maxDistance = RoomFactory.roomDepth - 0.4 - geometry.frontZ
        let tilt = atan(verticalTan / 2)

        var transform = Transform()
        transform.translation = [center.x, center.y, center.z + min(distance, maxDistance)]
        transform.rotation = simd_quatf(angle: -tilt, axis: [1, 0, 0])
        return transform
    }

    // MARK: Presenting a book

    private static let slideOutDuration = 0.3
    private static let flyDuration = 0.6
    /// Front cover towards the camera, turned a little so the spine shows and it reads as 3D.
    private static let presentedYaw: Float = -.pi / 2 + 0.28

    /// Slides the book out of the shelf, then flies it up to the camera, turning to show its front cover.
    /// Returns once the animation has finished.
    func present(bookID: UUID) async {
        if presented != nil { dismissPresentedImmediately() }
        guard let entity = bookEntities[bookID], let book = bookSnapshots[bookID] else { return }
        let dimensions = BookDimensions(pages: book.totalPages, id: book.id)
        let rest = entity.transform
        presented = Presented(id: bookID, entity: entity, rest: rest, dimensions: dimensions)
        BookEntityFactory.addCoverIfNeeded(to: entity, book: book, dimensions: dimensions)
        let target = presentationTransform(dimensions, yaw: 0)

        if reduceMotion {
            showDimmer(behind: dimensions)
            entity.setTransformMatrix(target.matrix, relativeTo: nil)
            return
        }

        var out = rest
        out.translation.z += 0.2
        entity.move(to: out, relativeTo: entity.parent, duration: Self.slideOutDuration, timingFunction: .easeOut)
        try? await Task.sleep(for: .seconds(Self.slideOutDuration))
        guard presented?.id == bookID, let current = presented?.entity else { return }

        showDimmer(behind: dimensions)
        current.move(to: target, relativeTo: nil, duration: Self.flyDuration, timingFunction: .easeInOut)
        try? await Task.sleep(for: .seconds(Self.flyDuration))
    }

    /// Flies the book back into its slot on the shelf.
    func dismissPresented() async {
        guard let current = presented else { return }
        presented = nil
        dimmer.isEnabled = false
        if reduceMotion {
            current.entity.transform = current.rest
            return
        }
        var out = current.rest
        out.translation.z += 0.2
        current.entity.move(to: out, relativeTo: current.entity.parent, duration: Self.flyDuration, timingFunction: .easeInOut)
        try? await Task.sleep(for: .seconds(Self.flyDuration))
        current.entity.move(to: current.rest, relativeTo: current.entity.parent, duration: Self.slideOutDuration, timingFunction: .easeIn)
    }

    /// Puts the book back without animating, e.g. before it's deleted.
    func dismissPresentedImmediately() {
        guard let current = presented else { return }
        presented = nil
        dimmer.isEnabled = false
        current.entity.transform = current.rest
    }

    /// Turns the presented book around its vertical axis while the user drags.
    func rotatePresented(dragWidth: CGFloat) {
        guard var current = presented else { return }
        let start = current.dragStartYaw ?? current.yaw
        current.dragStartYaw = start
        current.yaw = start + Float(dragWidth / 120)
        presented = current
        current.entity.setOrientation(presentationTransform(current.dimensions, yaw: current.yaw).rotation, relativeTo: nil)
    }

    func endRotatePresented() {
        presented?.dragStartYaw = nil
    }

    /// Pose in front of the camera where the book fills most of the space between the top bar and the buttons.
    private func presentationTransform(_ d: BookDimensions, yaw: Float) -> Transform {
        let fov = camera.camera.fieldOfViewInDegrees * .pi / 180
        let verticalTan = tan(fov / 2)
        let horizontalTan = verticalTan * viewAspect
        // Share of the screen height / width the cover should take.
        let heightShare: Float = 0.46
        let widthShare: Float = 0.64
        let distance = max(d.height / (2 * verticalTan * heightShare), d.depth / (2 * horizontalTan * widthShare))
        // Lift it a little so the Log reading / Edit buttons fit underneath.
        let lift = distance * verticalTan * 0.14
        var transform = Transform()
        transform.translation = cameraTarget.translation + cameraTarget.rotation.act(SIMD3(0, lift, -distance))
        transform.rotation = cameraTarget.rotation * simd_quatf(angle: Self.presentedYaw + yaw, axis: [0, 1, 0])
        return transform
    }

    private func showDimmer(behind d: BookDimensions) {
        let bookDistance = simd_distance(presentationTransform(d, yaw: 0).translation, cameraTarget.translation)
        dimmer.transform = Transform(
            rotation: cameraTarget.rotation,
            translation: cameraTarget.translation + cameraTarget.rotation.act(SIMD3(0, 0, -(bookDistance + 0.15)))
        )
        dimmer.isEnabled = true
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
