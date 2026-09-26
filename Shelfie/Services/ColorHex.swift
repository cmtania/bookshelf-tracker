import SwiftUI
import UIKit

extension UIColor {
    /// "#RRGGBB" or "RRGGBB". Anything else falls back to mid grey.
    convenience init(hex: String) {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("#") { string.removeFirst() }
        guard string.count == 6, let value = UInt64(string, radix: 16) else {
            self.init(white: 0.5, alpha: 1)
            return
        }
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    var luminance: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

enum Palette {
    /// Book-cloth colours, used for spines and categories.
    static let colors: [String] = [
        "#9F1D20", // oxblood
        "#C2571A", // burnt orange
        "#C99A2E", // mustard
        "#2F6B3F", // forest
        "#1F6F6B", // teal
        "#1F3A68", // navy
        "#3B4CCA", // royal blue
        "#6B2E6B", // plum
        "#B03A5B", // rose
        "#3A3A3A", // charcoal
    ]

    /// Readable text colour on top of a spine colour.
    static func ink(on hex: String) -> Color {
        UIColor(hex: hex).luminance > 0.55 ? Color(hex: "#1B1B1B") : Color(hex: "#FAF7F0")
    }
}
