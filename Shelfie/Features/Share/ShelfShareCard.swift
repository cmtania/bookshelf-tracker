import SwiftUI

/// The image people share: just the bookcase and its books (no walls or floor) on a soft
/// background, with a heading and a small app credit. Drawn in 2D from the same layout as
/// the 3D shelf, at 4:5 for Instagram and other feeds (1080 × 1350 px at 3x).
struct ShelfShareCard: View {
    static let size = CGSize(width: 360, height: 450)

    let snapshot: ShelfSnapshot
    let shelf: RoomTheme.Preset
    let bookCount: Int
    let readingCount: Int
    let finishedCount: Int
    let streak: Int

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("My Bookshelf")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                Text(statsLine)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: "#6B645A"))
            }

            BookcaseDrawing(snapshot: snapshot, shelf: shelf)
                .aspectRatio(CGFloat(BookcaseGeometry().width / BookcaseGeometry().height), contentMode: .fit)
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
        if streak > 0 { parts.append("🔥 \(streak)-day streak") }
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

/// Front view of the bookcase: frame, shaded compartments, books, and category labels.
private struct BookcaseDrawing: View {
    let snapshot: ShelfSnapshot
    let shelf: RoomTheme.Preset

    var body: some View {
        Canvas { context, size in
            let g = BookcaseGeometry()
            let scale = size.width / CGFloat(g.width)
            func x(_ metres: Float) -> CGFloat { CGFloat(metres + g.width / 2) * scale }
            func y(_ metres: Float) -> CGFloat { CGFloat(g.height - metres) * scale }
            /// Rect from a bottom-left corner and size, all in metres.
            func rect(_ left: Float, _ bottom: Float, _ width: Float, _ height: Float) -> CGRect {
                CGRect(x: x(left), y: y(bottom + height), width: CGFloat(width) * scale, height: CGFloat(height) * scale)
            }

            let paint = UIColor(hex: shelf.hex)
            // Frame.
            let frameRect = rect(-g.width / 2, 0, g.width, g.height)
            context.fill(Path(roundedRect: frameRect, cornerRadius: 2), with: .color(Color(uiColor: paint)))
            if shelf.finish != .matte {
                // Lacquer and metal get a diagonal sheen across the frame (compartments are drawn on top).
                let strength = shelf.finish == .metallic ? 0.45 : 0.25
                context.fill(
                    Path(roundedRect: frameRect, cornerRadius: 2),
                    with: .linearGradient(
                        Gradient(colors: [.white.opacity(strength), .clear, .black.opacity(strength * 0.5), .white.opacity(strength * 0.6)]),
                        startPoint: CGPoint(x: frameRect.minX, y: frameRect.minY),
                        endPoint: CGPoint(x: frameRect.maxX, y: frameRect.maxY)
                    )
                )
            }
            context.fill(Path(rect(-g.width / 2 + g.board, 0, g.width - 2 * g.board, g.plinth)), with: .color(Color(uiColor: paint.adjustingBrightness(by: 0.9))))

            for compartment in snapshot.compartments {
                let origin = g.origin(of: compartment.index)
                let inside = rect(origin.x, origin.y, g.innerWidth, g.rowHeight)
                // Back panel, with a soft shadow under the shelf above.
                context.fill(Path(inside), with: .color(Color(uiColor: paint.adjustingBrightness(by: 0.88))))
                let shadowHeight = inside.height * 0.18
                context.fill(
                    Path(CGRect(x: inside.minX, y: inside.minY, width: inside.width, height: shadowHeight)),
                    with: .linearGradient(
                        Gradient(colors: [.black.opacity(0.22), .clear]),
                        startPoint: CGPoint(x: inside.midX, y: inside.minY),
                        endPoint: CGPoint(x: inside.midX, y: inside.minY + shadowHeight)
                    )
                )

                let layout = CompartmentLayout(compartment, geometry: g)
                for entry in layout.entries {
                    drawBook(entry, layout: layout, origin: origin, in: &context, rect: rect)
                }
            }

            // Labels last, in a second pass: each one hangs down from its shelf edge into the
            // compartment below, so drawing it before that compartment would paint over its lower half.
            for compartment in snapshot.compartments {
                guard let name = compartment.name else { continue }
                let layout = CompartmentLayout(compartment, geometry: g)
                drawPlate(name, hidden: layout.hiddenCount, origin: g.origin(of: compartment.index), geometry: g, in: &context, rect: rect)
            }
        }
    }

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
        origin: SIMD3<Float>,
        geometry g: BookcaseGeometry,
        in context: inout GraphicsContext,
        rect: (Float, Float, Float, Float) -> CGRect
    ) {
        // Same size and position as the 3D label: top at the board's top, hanging down.
        let width = BookcaseFactory.plateWidth
        let height = BookcaseFactory.plateHeight
        let plate = rect(origin.x + g.innerWidth / 2 - width / 2, origin.y - height, width, height)
        context.fill(Path(roundedRect: plate, cornerRadius: plate.height * 0.25), with: .color(.white))
        let label = hidden > 0 ? "\(name) · +\(hidden)" : name
        // One line, centred on the plate, shrunk to fit if the name is long, so it's never cut.
        let bounds = plate.insetBy(dx: plate.height * 0.3, dy: 0)
        var fontSize = plate.height * 0.58
        var text = context.resolve(labelText(label, size: fontSize))
        let unlimited = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let width = text.measure(in: unlimited).width
        if width > bounds.width {
            fontSize *= max(0.5, bounds.width / width)
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
