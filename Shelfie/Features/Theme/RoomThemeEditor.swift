import SwiftUI

/// Pick the bookcase, wall and floor looks: a Classic row of plain colours and a Premium row of
/// lacquers, metals, designer wall colours and patterned floors. Opened as a short sheet over the
/// Bookshelf tab (so the 3D room updates live behind it) and from Settings. Part of the Unlock.
struct RoomThemeEditor: View {
    @AppStorage(Prefs.shelfColorKey) private var shelfID = RoomTheme.default.shelfID
    @AppStorage(Prefs.wallColorKey) private var wallID = RoomTheme.default.wallID
    @AppStorage(Prefs.floorColorKey) private var floorID = RoomTheme.default.floorID

    private var isDefault: Bool {
        RoomTheme(shelfID: shelfID, wallID: wallID, floorID: floorID) == .default
    }

    var body: some View {
        Form {
            partSection("Bookcase", presets: RoomTheme.shelfPresets, kind: .shelf, selection: $shelfID)
            partSection("Walls", presets: RoomTheme.wallPresets, kind: .wall, selection: $wallID)
            partSection("Floor", presets: RoomTheme.floorPresets, kind: .floor, selection: $floorID)
            Section {
                Button("Reset to default colors") {
                    shelfID = RoomTheme.default.shelfID
                    wallID = RoomTheme.default.wallID
                    floorID = RoomTheme.default.floorID
                }
                .disabled(isDefault)
            }
        }
    }

    private func partSection(_ title: String, presets: [RoomTheme.Preset], kind: Swatch.Kind, selection: Binding<String>) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                rowLabel("Classic")
                PresetSwatchRow(presets: presets.filter { !$0.isPremium }, kind: kind, selection: selection)
                rowLabel("Premium", systemImage: "sparkles")
                PresetSwatchRow(presets: presets.filter(\.isPremium), kind: kind, selection: selection)
            }
            .padding(.vertical, 4)
        } header: {
            HStack {
                Text(title)
                Spacer()
                Text(RoomTheme.resolve(selection.wrappedValue, in: presets).name)
                    .textCase(nil)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func rowLabel(_ text: String, systemImage: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }
}

/// A horizontal row of named swatches.
struct PresetSwatchRow: View {
    let presets: [RoomTheme.Preset]
    let kind: Swatch.Kind
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(presets) { preset in
                    let isSelected = preset.id == selection
                    Button {
                        withAnimation(.snappy) { selection = preset.id }
                    } label: {
                        VStack(spacing: 6) {
                            Swatch(preset: preset, kind: kind)
                                .frame(width: 40, height: 40)
                                .overlay {
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(Palette.ink(on: preset.hex))
                                            .shadow(color: .black.opacity(0.25), radius: 1)
                                    }
                                }
                                .padding(3)
                                .overlay(Circle().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2.5))
                            Text(preset.name)
                                .font(.caption2)
                                .foregroundStyle(isSelected ? .primary : .secondary)
                                .lineLimit(1)
                        }
                        .frame(minWidth: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.name)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }
}

/// One swatch: floors show their real pattern, glossy and metal finishes get a sheen.
struct Swatch: View {
    enum Kind {
        case shelf, wall, floor
    }

    let preset: RoomTheme.Preset
    let kind: Kind

    var body: some View {
        ZStack {
            if kind == .floor {
                Image(uiImage: TextureFactory.floorThumbnail(pattern: preset.pattern, hex: preset.hex))
                    .resizable()
                    .scaledToFill()
            } else {
                Color(hex: preset.hex)
                switch preset.finish {
                case .matte:
                    EmptyView()
                case .gloss:
                    // A soft highlight, like light on lacquer.
                    Ellipse()
                        .fill(.white.opacity(0.45))
                        .frame(width: 18, height: 10)
                        .blur(radius: 3)
                        .offset(x: -7, y: -10)
                case .metallic:
                    LinearGradient(
                        colors: [.white.opacity(0.55), .clear, .black.opacity(0.25), .white.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.primary.opacity(0.12)))
    }
}
