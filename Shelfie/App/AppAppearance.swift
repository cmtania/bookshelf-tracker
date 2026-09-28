import SwiftUI

/// Light or dark look for the whole app, chosen in Settings > Appearance.
/// "System" follows the device setting. The 3D room keeps its own colours either way, and the
/// text over it still follows the wall colour.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// nil lets the device decide.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
