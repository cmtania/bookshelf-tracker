import Foundation

/// Colours and finishes of the 3D room. Each part stores a preset id in UserDefaults (see Prefs).
/// Classic presets use their hex as the id, so values saved before Premium existed still resolve.
struct RoomTheme: Equatable {
    enum Finish: String {
        case matte, gloss, metallic
    }

    enum FloorPattern: String {
        case planks, herringbone, marble, terrazzo, checker
    }

    struct Preset: Identifiable, Equatable {
        let id: String
        let name: String
        let hex: String
        var finish: Finish = .matte
        var pattern: FloorPattern = .planks
        var isPremium = false

        static func classic(_ name: String, _ hex: String) -> Preset {
            Preset(id: hex, name: name, hex: hex)
        }

        static func premium(_ id: String, _ name: String, _ hex: String, finish: Finish = .matte, pattern: FloorPattern = .planks) -> Preset {
            Preset(id: id, name: name, hex: hex, finish: finish, pattern: pattern, isPremium: true)
        }
    }

    var shelfID: String
    var wallID: String
    var floorID: String

    var shelf: Preset { Self.resolve(shelfID, in: Self.shelfPresets) }
    var wall: Preset { Self.resolve(wallID, in: Self.wallPresets) }
    var floor: Preset { Self.resolve(floorID, in: Self.floorPresets) }

    static let `default` = RoomTheme(shelfID: shelfPresets[0].id, wallID: wallPresets[0].id, floorID: floorPresets[0].id)

    /// Unknown ids fall back to a plain colour if they look like a hex, else to the first preset.
    static func resolve(_ id: String, in presets: [Preset]) -> Preset {
        if let preset = presets.first(where: { $0.id == id }) { return preset }
        if id.hasPrefix("#") { return .classic("Custom", id) }
        return presets[0]
    }

    // MARK: Bookcase

    static let shelfPresets: [Preset] = [
        .classic("White", "#F1EFEA"),
        .classic("Oak", "#C89B6D"),
        .classic("Walnut", "#6B4A32"),
        .classic("Black", "#2B2B2D"),
        .classic("Sage", "#9CAF94"),
        .classic("Navy", "#2E3F5C"),
        .classic("Blush", "#E8C4C0"),
        .classic("Mustard", "#D6A94A"),
        .premium("emerald-lacquer", "Emerald lacquer", "#1F5E4A", finish: .gloss),
        .premium("burgundy-lacquer", "Burgundy lacquer", "#6E1F2E", finish: .gloss),
        .premium("midnight-lacquer", "Midnight lacquer", "#1B2340", finish: .gloss),
        .premium("ivory-gloss", "Ivory gloss", "#F3EDE0", finish: .gloss),
        .premium("ebony-gloss", "Ebony gloss", "#1A1716", finish: .gloss),
        .premium("brass", "Brushed brass", "#B8903F", finish: .metallic),
        .premium("rose-gold", "Rose gold", "#C99A86", finish: .metallic),
        .premium("champagne", "Champagne", "#D8C7A1", finish: .metallic),
        .premium("gunmetal", "Gunmetal", "#4A4E55", finish: .metallic),
    ]

    // MARK: Walls

    static let wallPresets: [Preset] = [
        .classic("White", "#F3F2EF"),
        .classic("Cream", "#F4EBDD"),
        .classic("Sage", "#DDE5D8"),
        .classic("Sky", "#DCE8F2"),
        .classic("Blush", "#F3DEDC"),
        .classic("Greige", "#D9D3CA"),
        .classic("Terracotta", "#C9876A"),
        .classic("Charcoal", "#4A4B4F"),
        .premium("hunter-green", "Hunter green", "#2F4A3A"),
        .premium("midnight-blue", "Midnight blue", "#22304A"),
        .premium("aubergine", "Aubergine", "#4B2C45"),
        .premium("ochre", "Ochre", "#C28A3A"),
        .premium("dusty-rose", "Dusty rose", "#C9A3A0"),
        .premium("deep-teal", "Deep teal", "#1E5A5E"),
        .premium("oxblood", "Oxblood", "#5E2226"),
        .premium("warm-linen", "Warm linen", "#E9DFCC"),
    ]

    // MARK: Floors

    static let floorPresets: [Preset] = [
        .classic("Light oak", "#D9B98C"),
        .classic("Honey", "#C8955C"),
        .classic("Walnut", "#7A5236"),
        .classic("Ash", "#B9B3AA"),
        .classic("Whitewash", "#E6DFD3"),
        .classic("Ebony", "#3F3029"),
        .premium("herringbone-oak", "Oak herringbone", "#C8A26E", pattern: .herringbone),
        .premium("herringbone-walnut", "Walnut herringbone", "#6E4A31", pattern: .herringbone),
        .premium("marble-white", "White marble", "#ECEAE6", pattern: .marble),
        .premium("marble-black", "Black marble", "#2A2A2C", pattern: .marble),
        .premium("terrazzo", "Terrazzo", "#E7E1D6", pattern: .terrazzo),
        .premium("checker", "Checkerboard", "#1F1F21", pattern: .checker),
    ]
}
