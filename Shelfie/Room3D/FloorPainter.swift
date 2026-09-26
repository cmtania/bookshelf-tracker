import UIKit

/// Draws floor textures with CoreGraphics: planks, herringbone, marble, terrazzo and checkerboard.
/// Deterministic (seeded), so a floor looks the same every launch. Used for the 3D floor and
/// for the small previews in the room colour picker.
enum FloorPainter {
    static func image(pattern: RoomTheme.FloorPattern, hex: String, size: CGSize, pixelsPerMeter ppm: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            var rng = SplitMix64(seed: 7)
            let base = RGB(hex)
            switch pattern {
            case .planks:
                planks(cg, size: size, ppm: ppm, base: base, rng: &rng)
            case .herringbone:
                herringbone(cg, size: size, ppm: ppm, base: base, rng: &rng)
            case .marble:
                marble(cg, size: size, ppm: ppm, base: base, rng: &rng)
            case .terrazzo:
                terrazzo(cg, size: size, ppm: ppm, base: base, rng: &rng)
            case .checker:
                checker(cg, size: size, ppm: ppm, base: base)
            }
        }
    }

    // MARK: Patterns

    private static func planks(_ cg: CGContext, size: CGSize, ppm: CGFloat, base: RGB, rng: inout SplitMix64) {
        let rowHeight = 0.18 * ppm
        var top: CGFloat = 0
        while top < size.height {
            var x = -CGFloat.random(in: 0...ppm, using: &rng)
            while x < size.width {
                let length = CGFloat.random(in: (0.8 * ppm)...(1.4 * ppm), using: &rng)
                base.shaded(CGFloat.random(in: 0.93...1.07, using: &rng)).setFill()
                cg.fill(CGRect(x: x, y: top, width: length, height: rowHeight))
                UIColor(white: 0, alpha: 0.05).setFill()
                for _ in 0..<3 {
                    let grainY = top + CGFloat.random(in: 2...max(3, rowHeight - 2), using: &rng)
                    cg.fill(CGRect(x: x, y: grainY, width: length, height: 1))
                }
                UIColor(white: 0, alpha: 0.12).setFill()
                cg.fill(CGRect(x: x, y: top, width: 1.5, height: rowHeight))
                x += length
            }
            UIColor(white: 0, alpha: 0.10).setFill()
            cg.fill(CGRect(x: 0, y: top, width: size.width, height: 1))
            top += rowHeight
        }
    }

    /// Classic herringbone: drawn in a frame turned 45°, where it's a staircase of alternating
    /// horizontal (L × W) and vertical (W × L) planks, repeated every (L, -L).
    private static func herringbone(_ cg: CGContext, size: CGSize, ppm: CGFloat, base: RGB, rng: inout SplitMix64) {
        let w = 0.09 * ppm
        let l = 0.45 * ppm
        base.shaded(0.82).setFill()
        cg.fill(CGRect(origin: .zero, size: size))

        cg.saveGState()
        cg.translateBy(x: size.width / 2, y: size.height / 2)
        cg.rotate(by: .pi / 4)
        let reach = hypot(size.width, size.height)
        let nRange = Int(reach / w) + 2
        let jRange = Int(reach / l) + 2

        func plank(_ rect: CGRect, _ rng: inout SplitMix64) {
            base.shaded(CGFloat.random(in: 0.9...1.08, using: &rng)).setFill()
            cg.fill(rect.insetBy(dx: 0.6, dy: 0.6))
        }

        for j in -jRange...jRange {
            for n in -nRange...nRange {
                let originX = CGFloat(n) * w + CGFloat(j) * l
                let originY = CGFloat(n) * w - CGFloat(j) * l
                guard abs(originX) < reach + l, abs(originY) < reach + l else { continue }
                plank(CGRect(x: originX, y: originY, width: l, height: w), &rng)
                plank(CGRect(x: originX, y: originY + w, width: w, height: l), &rng)
            }
        }
        cg.restoreGState()
    }

    private static func marble(_ cg: CGContext, size: CGSize, ppm: CGFloat, base: RGB, rng: inout SplitMix64) {
        base.color.setFill()
        cg.fill(CGRect(origin: .zero, size: size))

        // Soft clouds.
        let cloud = UIColor(white: base.isDark ? 1 : 0, alpha: 0.03)
        for _ in 0..<40 {
            let radius = CGFloat.random(in: 0.2...0.6, using: &rng) * ppm
            let center = randomPoint(in: size, rng: &rng)
            cloud.setFill()
            cg.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }

        // Veins: meandering curves.
        let vein = base.isDark ? UIColor(white: 0.85, alpha: 0.35) : UIColor(white: 0.35, alpha: 0.28)
        cg.setLineCap(.round)
        cg.setStrokeColor(vein.cgColor)
        let area = (size.width / ppm) * (size.height / ppm)
        let veinCount = Int(area * 1.2) + 3
        for _ in 0..<veinCount {
            var point = randomPoint(in: size, rng: &rng)
            let path = CGMutablePath()
            path.move(to: point)
            var angle = CGFloat.random(in: 0...(2 * .pi), using: &rng)
            for _ in 0..<6 {
                angle += CGFloat.random(in: -0.6...0.6, using: &rng)
                let step = CGFloat.random(in: 0.15...0.4, using: &rng) * ppm
                let next = CGPoint(x: point.x + cos(angle) * step, y: point.y + sin(angle) * step)
                let control = CGPoint(
                    x: (point.x + next.x) / 2 + CGFloat.random(in: -0.08...0.08, using: &rng) * ppm,
                    y: (point.y + next.y) / 2 + CGFloat.random(in: -0.08...0.08, using: &rng) * ppm
                )
                path.addQuadCurve(to: next, control: control)
                point = next
            }
            cg.addPath(path)
            cg.setLineWidth(max(0.6, CGFloat.random(in: 0.6...2.2, using: &rng) * ppm / 200))
            cg.strokePath()
        }

        tileJoints(cg, size: size, spacing: 0.6 * ppm, color: UIColor(white: base.isDark ? 1 : 0, alpha: 0.08))
    }

    private static func terrazzo(_ cg: CGContext, size: CGSize, ppm: CGFloat, base: RGB, rng: inout SplitMix64) {
        base.color.setFill()
        cg.fill(CGRect(origin: .zero, size: size))
        let palette = ["#B85C38", "#6E8B74", "#2F3E46", "#D9A441", "#9A8C7B", "#FFFFFF", "#C9C2B6"].map { UIColor(hex: $0) }
        let area = (size.width / ppm) * (size.height / ppm)
        let chips = Int(area * 600)
        for _ in 0..<chips {
            let radius = CGFloat.random(in: 0.004...0.014, using: &rng) * ppm
            let center = randomPoint(in: size, rng: &rng)
            palette[Int.random(in: 0..<palette.count, using: &rng)].setFill()
            cg.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius * 0.8, width: radius * 2, height: radius * 1.6))
        }
    }

    private static func checker(_ cg: CGContext, size: CGSize, ppm: CGFloat, base: RGB) {
        let tile = 0.45 * ppm
        let light = UIColor(hex: "#ECE8E1")
        let rows = Int((size.height / tile).rounded(.up))
        let columns = Int((size.width / tile).rounded(.up))
        for row in 0..<rows {
            for column in 0..<columns {
                ((row + column).isMultiple(of: 2) ? base.color : light).setFill()
                cg.fill(CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile))
            }
        }
        tileJoints(cg, size: size, spacing: tile, color: UIColor(white: 0.5, alpha: 0.2))
    }

    // MARK: Helpers

    private static func tileJoints(_ cg: CGContext, size: CGSize, spacing: CGFloat, color: UIColor) {
        color.setFill()
        var x: CGFloat = 0
        while x < size.width {
            cg.fill(CGRect(x: x, y: 0, width: 1, height: size.height))
            x += spacing
        }
        var y: CGFloat = 0
        while y < size.height {
            cg.fill(CGRect(x: 0, y: y, width: size.width, height: 1))
            y += spacing
        }
    }

    private static func randomPoint(in size: CGSize, rng: inout SplitMix64) -> CGPoint {
        CGPoint(x: CGFloat.random(in: 0...size.width, using: &rng), y: CGFloat.random(in: 0...size.height, using: &rng))
    }

    private struct RGB {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0

        init(_ hex: String) {
            var alpha: CGFloat = 0
            UIColor(hex: hex).getRed(&r, green: &g, blue: &b, alpha: &alpha)
        }

        var color: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }

        func shaded(_ factor: CGFloat) -> UIColor {
            UIColor(red: min(1, r * factor), green: min(1, g * factor), blue: min(1, b * factor), alpha: 1)
        }

        var isDark: Bool { 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.45 }
    }
}
