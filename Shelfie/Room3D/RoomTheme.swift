import Foundation

/// Colours of the 3D room. Stored in UserDefaults (see Prefs) so every screen agrees.
struct RoomTheme: Equatable {
    struct Preset: Identifiable, Equatable {
        let name: String
        let hex: String
        var id: String { hex }
    }

    var shelfHex: String
    var wallHex: String
    var floorHex: String

    static let `default` = RoomTheme(shelfHex: shelfPresets[0].hex, wallHex: wallPresets[0].hex, floorHex: floorPresets[0].hex)

    static let shelfPresets: [Preset] = [
        Preset(name: "White", hex: "#F1EFEA"),
        Preset(name: "Oak", hex: "#C89B6D"),
        Preset(name: "Walnut", hex: "#6B4A32"),
        Preset(name: "Black", hex: "#2B2B2D"),
        Preset(name: "Sage", hex: "#9CAF94"),
        Preset(name: "Navy", hex: "#2E3F5C"),
        Preset(name: "Blush", hex: "#E8C4C0"),
        Preset(name: "Mustard", hex: "#D6A94A"),
    ]

    static let wallPresets: [Preset] = [
        Preset(name: "White", hex: "#F3F2EF"),
        Preset(name: "Cream", hex: "#F4EBDD"),
        Preset(name: "Sage", hex: "#DDE5D8"),
        Preset(name: "Sky", hex: "#DCE8F2"),
        Preset(name: "Blush", hex: "#F3DEDC"),
        Preset(name: "Greige", hex: "#D9D3CA"),
        Preset(name: "Terracotta", hex: "#C9876A"),
        Preset(name: "Charcoal", hex: "#4A4B4F"),
    ]

    static let floorPresets: [Preset] = [
        Preset(name: "Light oak", hex: "#D9B98C"),
        Preset(name: "Honey", hex: "#C8955C"),
        Preset(name: "Walnut", hex: "#7A5236"),
        Preset(name: "Ash", hex: "#B9B3AA"),
        Preset(name: "Whitewash", hex: "#E6DFD3"),
        Preset(name: "Ebony", hex: "#3F3029"),
    ]
}
