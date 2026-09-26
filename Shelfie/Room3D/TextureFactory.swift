import RealityKit
import SwiftUI
import UIKit

/// Renders SwiftUI views / CoreGraphics drawings into RealityKit textures, cached by content.
@MainActor
enum TextureFactory {
    /// How many SwiftUI points one metre of spine becomes before the 2x render scale.
    static let pointsPerMeter: CGFloat = 1400
    private static var cache: [String: TextureResource] = [:]

    static func spine(title: String, author: String, colorHex: String, width: Float, height: Float) -> TextureResource? {
        let key = "spine|\(title)|\(author)|\(colorHex)|\(width)|\(height)"
        if let cached = cache[key] { return cached }
        let size = CGSize(width: CGFloat(width) * pointsPerMeter, height: CGFloat(height) * pointsPerMeter)
        let texture = render(SpineArt(title: title, colorHex: colorHex, size: size))
        cache[key] = texture
        return texture
    }

    /// Front cover, rendered sharper than spines because it's shown filling the screen.
    static func cover(title: String, author: String, colorHex: String, width: Float, height: Float) -> TextureResource? {
        let key = "cover|\(title)|\(author)|\(colorHex)|\(width)|\(height)"
        if let cached = cache[key] { return cached }
        let size = CGSize(width: CGFloat(width) * pointsPerMeter, height: CGFloat(height) * pointsPerMeter)
        let texture = render(CoverArt(title: title, author: author, colorHex: colorHex, size: size), scale: 3)
        cache[key] = texture
        return texture
    }

    static func plate(text: String, isPlaceholder: Bool, width: Float, height: Float) -> TextureResource? {
        let key = "plate|\(text)|\(isPlaceholder)|\(width)|\(height)"
        if let cached = cache[key] { return cached }
        let size = CGSize(width: CGFloat(width) * pointsPerMeter, height: CGFloat(height) * pointsPerMeter)
        let texture = render(PlateArt(text: text, isPlaceholder: isPlaceholder, size: size))
        cache[key] = texture
        return texture
    }

    /// Light oak planks, like the reference room. Deterministic, so it looks the same every launch.
    static func woodFloor() -> TextureResource? {
        if let cached = cache["wood"] { return cached }
        let pixels = 1024
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: pixels, height: pixels), format: format).image { context in
            let cg = context.cgContext
            var rng = SplitMix64(seed: 7)
            let rows = 40
            let rowHeight = CGFloat(pixels) / CGFloat(rows)
            for row in 0..<rows {
                let top = CGFloat(row) * rowHeight
                var x = -CGFloat(Int.random(in: 0...180, using: &rng))
                while x < CGFloat(pixels) {
                    let length = CGFloat(Int.random(in: 150...260, using: &rng))
                    let tone = 0.80 + CGFloat(Int.random(in: 0...100, using: &rng)) / 1000
                    UIColor(red: tone, green: tone * 0.84, blue: tone * 0.64, alpha: 1).setFill()
                    cg.fill(CGRect(x: x, y: top, width: length, height: rowHeight))
                    UIColor(white: 0, alpha: 0.05).setFill()
                    for _ in 0..<3 {
                        let grainY = top + CGFloat(Int.random(in: 2...Int(rowHeight) - 2, using: &rng))
                        cg.fill(CGRect(x: x, y: grainY, width: length, height: 1))
                    }
                    UIColor(white: 0, alpha: 0.12).setFill()
                    cg.fill(CGRect(x: x, y: top, width: 1.5, height: rowHeight))
                    x += length
                }
                UIColor(white: 0, alpha: 0.10).setFill()
                cg.fill(CGRect(x: 0, y: top, width: CGFloat(pixels), height: 1))
            }
        }
        guard let cgImage = image.cgImage else { return nil }
        let texture = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color))
        cache["wood"] = texture
        return texture
    }

    private static func render<V: View>(_ view: V, scale: CGFloat = 2) -> TextureResource? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let cgImage = renderer.cgImage else { return nil }
        return try? TextureResource.generate(from: cgImage, options: .init(semantic: .color))
    }
}

/// Book spine: cloth colour, two thin bands, title running top to bottom.
private struct SpineArt: View {
    let title: String
    let colorHex: String
    let size: CGSize

    var body: some View {
        let ink = Palette.ink(on: colorHex)
        ZStack {
            Color(hex: colorHex)
            VStack(spacing: 0) {
                band(ink)
                Spacer(minLength: 0)
                band(ink)
            }
            .padding(.vertical, size.height * 0.05)
            Text(title)
                .font(.system(size: max(8, size.width * 0.42), weight: .semibold, design: .serif))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(width: size.height * 0.72, height: size.width * 0.9)
                .rotationEffect(.degrees(90))
        }
        .frame(width: size.width, height: size.height)
    }

    private func band(_ ink: Color) -> some View {
        Rectangle()
            .fill(ink.opacity(0.35))
            .frame(height: max(1, size.height * 0.012))
            .padding(.horizontal, size.width * 0.15)
    }
}

/// Front cover: cloth colour with a soft light falloff, an inset frame, the title and the author.
private struct CoverArt: View {
    let title: String
    let author: String
    let colorHex: String
    let size: CGSize

    var body: some View {
        let ink = Palette.ink(on: colorHex)
        ZStack {
            Color(hex: colorHex)
            LinearGradient(colors: [.white.opacity(0.10), .black.opacity(0.18)], startPoint: .top, endPoint: .bottom)
            RoundedRectangle(cornerRadius: size.width * 0.02)
                .strokeBorder(ink.opacity(0.45), lineWidth: max(1, size.width * 0.012))
                .padding(size.width * 0.06)
            VStack(spacing: size.height * 0.03) {
                Spacer(minLength: 0)
                Text(title)
                    .font(.system(size: size.width * 0.12, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.5)
                Rectangle()
                    .fill(ink.opacity(0.5))
                    .frame(width: size.width * 0.25, height: max(1, size.height * 0.006))
                if !author.isEmpty {
                    Text(author.uppercased())
                        .font(.system(size: size.width * 0.055, weight: .medium, design: .serif))
                        .tracking(size.width * 0.006)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
            .foregroundStyle(ink)
            .padding(.horizontal, size.width * 0.14)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Category label clipped to the front of a shelf board.
private struct PlateArt: View {
    let text: String
    let isPlaceholder: Bool
    let size: CGSize

    var body: some View {
        ZStack {
            Color(hex: isPlaceholder ? "#E4E1DA" : "#FFFFFF")
            Text(text)
                .font(.system(size: size.height * 0.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: isPlaceholder ? "#8A857B" : "#2B2B2B"))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, size.height * 0.3)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// Small deterministic RNG so the floor texture never changes between launches.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
