import SwiftUI

/// Preview of the share image, then the system share sheet (Instagram, Messages, Save Image…).
struct ShareShelfSheet: View {
    @Environment(\.dismiss) private var dismiss
    let card: ShelfShareCard

    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                            .accessibilityLabel("Picture of your bookshelf")
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)

                if let image {
                    ShareLink(
                        item: Image(uiImage: image),
                        preview: SharePreview("My Bookshelf", image: Image(uiImage: image))
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .padding(20)
            .navigationTitle("Share your shelf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if image == nil {
                    image = card.renderImage()
                }
            }
        }
    }
}
