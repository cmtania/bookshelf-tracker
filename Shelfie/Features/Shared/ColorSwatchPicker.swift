import SwiftUI

/// A grid of the book-cloth palette; the chosen colour gets a check mark.
struct ColorSwatchPicker: View {
    @Binding var selection: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(Palette.colors.enumerated()), id: \.element) { index, hex in
                Button {
                    selection = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 36, height: 36)
                        .overlay {
                            if selection == hex {
                                Image("ph-check")
                                    .font(.caption.bold())
                                    .foregroundStyle(Palette.ink(on: hex))
                            }
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Colour \(index + 1)")
                .accessibilityAddTraits(selection == hex ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
