import SwiftUI

/// Pick the bookcase, wall and floor looks. A dropdown chooses the part; below it are that part's
/// Classic and Premium swatches. Designed to fit a half-height sheet over the Bookshelf tab, where the
/// camera pulls back to show the whole room above it. Also pushed from Settings. Part of Shelfie Pro.
struct RoomThemeEditor: View {
    enum Part: String, CaseIterable, Identifiable {
        case design = "Design"
        case bookcase = "Bookcase color"
        case walls = "Walls"
        case floor = "Floor"

        var id: Self { self }

        var symbol: String {
            switch self {
            case .design: "square.split.2x2.fill"
            case .bookcase: "books.vertical.fill"
            case .walls: "square.fill"
            case .floor: "square.grid.3x3.fill"
            }
        }
    }

    @AppStorage(Prefs.shelfColorKey) private var shelfID = RoomTheme.default.shelfID
    @AppStorage(Prefs.wallColorKey) private var wallID = RoomTheme.default.wallID
    @AppStorage(Prefs.floorColorKey) private var floorID = RoomTheme.default.floorID
    @AppStorage(Prefs.bookcaseStyleKey) private var styleID = RoomTheme.default.styleID

    @State private var part: Part = .design

    private var theme: RoomTheme {
        RoomTheme(shelfID: shelfID, wallID: wallID, floorID: floorID, styleID: styleID)
    }

    private var isDefault: Bool { theme == .default }

    private var presets: [RoomTheme.Preset] {
        switch part {
        case .design, .bookcase: RoomTheme.shelfPresets
        case .walls: RoomTheme.wallPresets
        case .floor: RoomTheme.floorPresets
        }
    }

    private var selection: Binding<String> {
        switch part {
        case .design, .bookcase: $shelfID
        case .walls: $wallID
        case .floor: $floorID
        }
    }

    private var kind: Swatch.Kind {
        switch part {
        case .design, .bookcase: .shelf
        case .walls: .wall
        case .floor: .floor
        }
    }

    private var selectedName: String {
        part == .design ? theme.style.name : RoomTheme.resolve(selection.wrappedValue, in: presets).name
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    partMenu
                    Spacer(minLength: 8)
                    Text(selectedName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                }

                if part == .design {
                    designPicker
                } else {
                    rowLabel("Classic")
                    PresetSwatchRow(presets: presets.filter { !$0.isPremium }, kind: kind, selection: selection)
                    rowLabel("Premium", systemImage: "sparkles")
                    PresetSwatchRow(presets: presets.filter(\.isPremium), kind: kind, selection: selection)
                }

                Button("Reset to default") {
                    withAnimation(.snappy) {
                        shelfID = RoomTheme.default.shelfID
                        wallID = RoomTheme.default.wallID
                        floorID = RoomTheme.default.floorID
                        styleID = RoomTheme.default.styleID
                    }
                }
                .font(.subheadline.weight(.semibold))
                .disabled(isDefault)
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            // Swatch rows swap in place when the part changes.
            .id(part)
            .transition(.opacity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .animation(.snappy, value: part)
    }

    /// A card per bookcase design, each drawn with a sample shelf in the current colors.
    private var designPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(BookcaseStyle.allCases) { style in
                    let isSelected = style.rawValue == styleID
                    let preview = RoomTheme(shelfID: shelfID, wallID: wallID, floorID: floorID, styleID: style.rawValue)
                    let layout = style.layout
                    Button {
                        withAnimation(.snappy) { styleID = style.rawValue }
                    } label: {
                        VStack(spacing: 8) {
                            BookcaseDrawing(snapshot: .sample, theme: preview, showsLabels: false)
                                .aspectRatio(CGFloat(layout.width / layout.height), contentMode: .fit)
                                .frame(width: 84, height: 104)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: preview.wall.hex)))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: isSelected ? 2.5 : 1))
                            HStack(spacing: 3) {
                                if style.isPremium {
                                    Image(systemName: "sparkles")
                                        .font(.caption2)
                                        .foregroundStyle(Color.accentColor)
                                }
                                Text(style.name)
                                    .font(.caption.weight(isSelected ? .semibold : .regular))
                                    .foregroundStyle(isSelected ? .primary : .secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 108)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(style.name)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    /// Dropdown for which part of the room to color.
    private var partMenu: some View {
        Menu {
            Picker("Part of the room", selection: $part) {
                ForEach(Part.allCases) { item in
                    Label(item.rawValue, systemImage: item.symbol).tag(item)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: part.symbol)
                    .foregroundStyle(Color.accentColor)
                Text(part.rawValue)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .accessibilityLabel("Part of the room: \(part.rawValue)")
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
                                .frame(width: 44, height: 44)
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
                        .frame(minWidth: 60)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.name)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
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
