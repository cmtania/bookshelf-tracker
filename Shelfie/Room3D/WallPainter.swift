import UIKit

/// A very subtle painted-plaster texture: soft light/dark patches and a fine speckle in the
/// wall colour. Just enough that the walls read as real walls, not flat colour.
/// Deterministic (seeded), so the walls look the same every launch.
enum WallPainter {
    static func image(hex: String, size: CGSize, pixelsPerMeter ppm: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let base = UIColor(hex: hex)
        // On dark walls, variation shows more, so keep it even gentler.
        let strength: CGFloat = base.luminance < 0.4 ? 0.6 : 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            var rng = SplitMix64(seed: 11)
            base.setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            let area = (size.width / ppm) * (size.height / ppm)

            // Soft patches, like uneven paint coverage on plaster.
            for _ in 0..<Int(area * 14) {
                let radius = CGFloat.random(in: 0.15...0.5, using: &rng) * ppm
                let center = CGPoint(x: CGFloat.random(in: 0...size.width, using: &rng), y: CGFloat.random(in: 0...size.height, using: &rng))
                let light = Bool.random(using: &rng)
                UIColor(white: light ? 1 : 0, alpha: (light ? 0.035 : 0.025) * strength).setFill()
                cg.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius * 0.8, width: radius * 2, height: radius * 1.6))
            }

            // Fine speckle: the grain of the plaster.
            for _ in 0..<Int(area * 1800) {
                let point = CGPoint(x: CGFloat.random(in: 0...size.width, using: &rng), y: CGFloat.random(in: 0...size.height, using: &rng))
                let light = Bool.random(using: &rng)
                UIColor(white: light ? 1 : 0, alpha: (light ? 0.06 : 0.045) * strength).setFill()
                cg.fill(CGRect(x: point.x, y: point.y, width: 1.2, height: 1.2))
            }
        }
    }
}
