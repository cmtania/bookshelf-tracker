import SwiftUI

/// Pick the bookcase, wall and floor colours. Opened as a short sheet over the Bookshelf tab
/// (so the 3D room updates live behind it) and from Settings.
struct RoomThemeEditor: View {
    @AppStorage(Prefs.shelfColorKey) private var shelfHex = RoomTheme.default.shelfHex
    @AppStorage(Prefs.wallColorKey) private var wallHex = RoomTheme.default.wallHex
    @AppStorage(Prefs.floorColorKey) private var floorHex = RoomTheme.default.floorHex

    private var isDefault: Bool {
        RoomTheme(shelfHex: shelfHex, wallHex: wallHex, floorHex: floorHex) == .default
    }

    var body: some View {
        Form {
            Section("Bookcase") {
                PresetSwatchRow(presets: RoomTheme.shelfPresets, selection: $shelfHex)
            }
            Section("Walls") {
                PresetSwatchRow(presets: RoomTheme.wallPresets, selection: $wallHex)
            }
            Section("Floor") {
                PresetSwatchRow(presets: RoomTheme.floorPresets, selection: $floorHex)
            }
            Section {
                Button("Reset to default colors") {
                    shelfHex = RoomTheme.default.shelfHex
                    wallHex = RoomTheme.default.wallHex
                    floorHex = RoomTheme.default.floorHex
                }
                .disabled(isDefault)
            }
        }
    }
}

/// A horizontal row of named colour swatches.
struct PresetSwatchRow: View {
    let presets: [RoomTheme.Preset]
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(presets) { preset in
                    let isSelected = preset.hex == selection
                    Button {
                        withAnimation(.snappy) { selection = preset.hex }
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: preset.hex))
                                .frame(width: 40, height: 40)
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.12)))
                                .overlay {
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(Palette.ink(on: preset.hex))
                                    }
                                }
                                .padding(3)
                                .overlay(Circle().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2.5))
                            Text(preset.name)
                                .font(.caption2)
                                .foregroundStyle(isSelected ? .primary : .secondary)
                                .lineLimit(1)
                        }
                        .frame(minWidth: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.name)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
    }
}
