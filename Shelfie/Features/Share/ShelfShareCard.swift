import SwiftUI

/// The image people share: just the bookcase and its books (no room) on a soft background,
/// with a heading and a small app credit. Drawn in 2D from the same layout as the 3D shelf
/// (whatever bookcase design is chosen), at 4:5 for Instagram and other feeds (1080 × 1350 px at 3x).
struct ShelfShareCard: View {
    static let size = CGSize(width: 360, height: 450)

    let snapshot: ShelfSnapshot
    let theme: RoomTheme
    let bookCount: Int
    let readingCount: Int
    let finishedCount: Int
    let streak: Int

    var body: some View {
        let layout = theme.style.layout
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("My Bookshelf")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                Text(statsLine)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: "#6B645A"))
            }

            BookcaseDrawing(snapshot: snapshot, theme: theme)
                .aspectRatio(CGFloat(layout.width / layout.height), contentMode: .fit)
                .shadow(color: .black.opacity(0.22), radius: 14, y: 10)
                .frame(maxHeight: .infinity)

            HStack(spacing: 6) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16)
                Text("Shelfie")
                    .fontWeight(.semibold)
                Text("· my reading, on a 3D shelf")
                    .foregroundStyle(Color(hex: "#8A8378"))
            }
            .font(.system(size: 11, design: .rounded))
        }
        .foregroundStyle(Color(hex: "#2B2723"))
        .padding(.vertical, 22)
        .padding(.horizontal, 24)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(
            LinearGradient(colors: [Color(hex: "#FBF8F3"), Color(hex: "#EDE6DA")], startPoint: .top, endPoint: .bottom)
        )
    }

    private var statsLine: String {
        var parts = ["\(bookCount) \(bookCount == 1 ? "book" : "books")"]
        if readingCount > 0 { parts.append("\(readingCount) reading") }
        if finishedCount > 0 { parts.append("\(finishedCount) finished") }
        if streak > 0 { parts.append("\(streak)-day streak") }
        return parts.joined(separator: " · ")
    }

    /// Renders the card to an image for sharing.
    @MainActor
    func renderImage() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// Front view of the bookcase in any design: frame pieces (back to front), books, then labels.
/// Used by the share image and, with a sample shelf, for the design previews in Room colors.
struct BookcaseDrawing: View {
    let snapshot: ShelfSnapshot
    let theme: RoomTheme
    var showsLabels = true

    var body: some View {
        Canvas { context, size in
            let layout = theme.style.layout
            let scale = size.width / CGFloat(layout.width)
            func x(_ metres: Float) -> CGFloat { CGFloat(metres - layout.minX) * scale }
            func y(_ metres: Float) -> CGFloat { CGFloat(layout.maxY - metres) * scale }
            /// Rect from a bottom-left corner and size, all in metres.
            func rect(_ left: Float, _ bottom: Float, _ width: Float, _ height: Float) -> CGRect {
                CGRect(x: x(left), y: y(bottom + height), width: CGFloat(width) * scale, height: CGFloat(height) * scale)
            }

            // Pieces from the back to the front, so nearer ones cover farther ones (metal last at a tie).
            let pieces = layout.pieces.sorted { a, b in
                let frontA = a.center.z + a.size.z / 2
                let frontB = b.center.z + b.size.z / 2
                if abs(frontA - frontB) > 0.001 { return frontA < frontB }
                return (a.role == .metal ? 1 : 0) < (b.role == .metal ? 1 : 0)
            }
            for piece in pieces {
                drawPiece(piece, in: &context, scale: scale, x: x, y: y)
            }

            let slots = layout.slots
            for compartment in snapshot.compartments where compartment.index < slots.count {
                let slot = slots[compartment.index]
                let inside = rect(slot.origin.x, slot.origin.y, slot.width, slot.height)
                // A soft shadow under the shelf or box above.
                let shadowHeight = inside.height * 0.18
                context.fill(
                    Path(CGRect(x: inside.minX, y: inside.minY, width: inside.width, height: shadowHeight)),
                    with: .linearGradient(
                        Gradient(colors: [.black.opacity(0.18), .clear]),
                        startPoint: CGPoint(x: inside.midX, y: inside.minY),
                        endPoint: CGPoint(x: inside.midX, y: inside.minY + shadowHeight)
                    )
                )
                let books = CompartmentLayout(compartment, slot: slot)
                for entry in books.entries {
                    drawBook(entry, layout: books, origin: slot.origin, in: &context, rect: rect)
                }
            }

            // Labels last, in a second pass: each one hangs down from its shelf edge into the
            // compartment below, so drawing it earlier would get it painted over.
            guard showsLabels else { return }
            for compartment in snapshot.compartments where compartment.index < slots.count {
                guard let name = compartment.name else { continue }
                let slot = slots[compartment.index]
                let books = CompartmentLayout(compartment, slot: slot)
                drawPlate(name, hidden: books.hiddenCount, slot: slot, in: &context, rect: rect)
            }
        }
        .clipped()
    }

    // MARK: Pieces

    private func color(for role: FramePiece.Role) -> Color {
        switch role {
        case .paint: Color(hex: theme.shelf.hex)
        case .paintShade: Color(uiColor: UIColor(hex: theme.shelf.hex).adjustingBrightness(by: 0.86))
        case .metal: Color(hex: "#1E1F22")
        case .wall: Color(hex: theme.wall.hex)
        case .wallShade: Color(uiColor: UIColor(hex: theme.wall.hex).adjustingBrightness(by: 0.8))
        }
    }

    private func drawPiece(
        _ piece: FramePiece,
        in context: inout GraphicsContext,
        scale: CGFloat,
        x: (Float) -> CGFloat,
        y: (Float) -> CGFloat
    ) {
        let width = CGFloat(piece.size.x) * scale
        let height = CGFloat(piece.size.y) * scale
        var local = context
        local.translateBy(x: x(piece.center.x), y: y(piece.center.y))
        if piece.angle != 0 {
            // Canvas y points down, so a counter-clockwise angle in metres is clockwise here.
            local.rotate(by: .radians(-Double(piece.angle)))
        }
        let shape = Path(CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        local.fill(shape, with: .color(color(for: piece.role)))
        if piece.role == .paint && theme.shelf.finish != .matte {
            // Lacquer and metal finishes get a soft diagonal sheen.
            let strength = theme.shelf.finish == .metallic ? 0.4 : 0.22
            local.fill(
                shape,
                with: .linearGradient(
                    Gradient(colors: [.white.opacity(strength), .clear, .black.opacity(strength * 0.4)]),
                    startPoint: CGPoint(x: -width / 2, y: -height / 2),
                    endPoint: CGPoint(x: width / 2, y: height / 2)
                )
            )
        }
    }

    // MARK: Books and labels

    private func drawBook(
        _ entry: CompartmentLayout.Entry,
        layout: CompartmentLayout,
        origin: SIMD3<Float>,
        in context: inout GraphicsContext,
        rect: (Float, Float, Float, Float) -> CGRect
    ) {
        let d = entry.dimensions
        let cloth = UIColor(hex: entry.book.spineColorHex)
        let centerX = origin.x + layout.centerX(of: entry)
        let bottom = origin.y + layout.bottomY(of: entry)
        let bookRect: CGRect
        if entry.placement.lying {
            bookRect = rect(centerX - d.height / 2, bottom, d.height, d.thickness)
        } else {
            bookRect = rect(centerX - d.thickness / 2, bottom, d.thickness, d.height)
        }
        context.fill(Path(roundedRect: bookRect, cornerRadius: 0.6), with: .color(Color(uiColor: cloth)))

        let ink = Palette.ink(on: entry.book.spineColorHex).opacity(0.45)
        if entry.placement.lying {
            // Darker bottom edge, plus bands near both ends.
            context.fill(Path(CGRect(x: bookRect.minX, y: bookRect.maxY - bookRect.height * 0.18, width: bookRect.width, height: bookRect.height * 0.18)), with: .color(.black.opacity(0.18)))
            for fraction in [0.08, 0.9] {
                context.fill(Path(CGRect(x: bookRect.minX + bookRect.width * fraction, y: bookRect.minY, width: max(0.5, bookRect.width * 0.012), height: bookRect.height)), with: .color(ink))
            }
        } else {
            // Darker right edge for roundness, bands near top and bottom.
            context.fill(Path(CGRect(x: bookRect.maxX - bookRect.width * 0.2, y: bookRect.minY, width: bookRect.width * 0.2, height: bookRect.height)), with: .color(.black.opacity(0.18)))
            for fraction in [0.08, 0.9] {
                context.fill(Path(CGRect(x: bookRect.minX, y: bookRect.minY + bookRect.height * fraction, width: bookRect.width, height: max(0.5, bookRect.height * 0.012))), with: .color(ink))
            }
            if entry.book.status == .reading {
                // Bookmark ribbon sticking out of the top.
                let ribbon = rect(centerX - 0.003, bottom + d.height - 0.004, 0.006, 0.022)
                context.fill(Path(ribbon), with: .color(Color(hex: "#C0392B")))
            }
        }
    }

    private func drawPlate(
        _ name: String,
        hidden: Int,
        slot: CompartmentSlot,
        in context: inout GraphicsContext,
        rect: (Float, Float, Float, Float) -> CGRect
    ) {
        // Same size and position as the 3D label: top at the compartment floor, hanging down.
        let plateWidth = BookcaseFactory.labelWidth(for: slot)
        let plateHeight = BookcaseFactory.plateHeight
        let plate = rect(slot.origin.x + slot.width / 2 - plateWidth / 2, slot.origin.y - plateHeight, plateWidth, plateHeight)
        context.fill(Path(roundedRect: plate, cornerRadius: plate.height * 0.25), with: .color(.white))
        let label = hidden > 0 ? "\(name) · +\(hidden)" : name
        // One line, centred on the plate, shrunk to fit if the name is long, so it's never cut.
        let bounds = plate.insetBy(dx: plate.height * 0.3, dy: 0)
        var fontSize = plate.height * 0.58
        var text = context.resolve(labelText(label, size: fontSize))
        let unlimited = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let textWidth = text.measure(in: unlimited).width
        if textWidth > bounds.width {
            fontSize *= max(0.5, bounds.width / textWidth)
            text = context.resolve(labelText(label, size: fontSize))
        }
        context.draw(text, at: CGPoint(x: plate.midX, y: plate.midY), anchor: .center)
    }

    private func labelText(_ label: String, size: CGFloat) -> Text {
        Text(label)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: "#2B2B2B"))
    }
}

extension ShelfSnapshot {
    /// A made-up, well-filled shelf for the bookcase design previews. Fixed ids, so the
    /// books look the same every time.
    static let sample: ShelfSnapshot = {
        let counts = [4, 3, 5, 3, 4, 2, 3, 4, 2, 3]
        var number = 0
        let compartments = (0..<10).map { index -> CompartmentSnapshot in
            let books = (0..<counts[index]).map { position -> BookSnapshot in
                number += 1
                let id = UUID(uuidString: String(format: "%02X%06X-0000-0000-0000-%012d", (number * 53) % 256, number, number)) ?? UUID()
                return BookSnapshot(
                    id: id,
                    title: "",
                    author: "",
                    totalPages: 180 + (number * 97) % 420,
                    status: position == 0 && index % 3 == 0 ? .wantToRead : .finished,
                    spineColorHex: Palette.colors[number % Palette.colors.count]
                )
            }
            return CompartmentSnapshot(index: index, categoryID: UUID(), name: nil, books: books)
        }
        return ShelfSnapshot(compartments: compartments)
    }()
}
