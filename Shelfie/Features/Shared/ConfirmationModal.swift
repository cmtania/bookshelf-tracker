import SwiftUI

/// A centred confirmation card for destructive actions (deleting a book or a category):
/// an icon, the question, what will happen, and both buttons inside the card. The screen behind
/// dims; tapping it (or the Escape gesture) cancels.
///
/// It's shown in a transparent full-screen cover so it sits above the tab bar and any sheet,
/// and it animates itself (a short scale and fade) instead of sliding up like a cover.
struct ConfirmationCard: View {
    let title: String
    let message: String
    let confirmTitle: String
    var icon = "ph-trash"
    var onConfirm: () -> Void
    var onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    var body: some View {
        ZStack {
            Color.black
                .opacity(isShown ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture { close(then: onCancel) }
                .accessibilityHidden(true)

            if isShown {
                card
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.2)) {
                isShown = true
            }
        }
        .sensoryFeedback(.warning, trigger: isShown) { _, shown in shown }
    }

    private var card: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(icon)
                    .font(.title)
                    .foregroundStyle(.red)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color.red.opacity(0.12)))
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 8) {
                Button(role: .destructive) {
                    close(then: onConfirm)
                } label: {
                    Text(confirmTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(.red)

                Button {
                    close(then: onCancel)
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(24)
        .frame(maxWidth: 360)
        .glassEffect(.regular, in: .rect(cornerRadius: 32))
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { close(then: onCancel) }
    }

    /// Animates the card out, then runs the action (which also takes the cover away).
    private func close(then action: @escaping () -> Void) {
        guard isShown else { return }
        withAnimation(.easeIn(duration: 0.18)) {
            isShown = false
        }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            action()
        }
    }
}

extension View {
    /// Asks before a destructive action, in a centred card with its buttons inside.
    func confirmation(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String,
        confirmTitle: String,
        icon: String = "ph-trash",
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(ConfirmationModifier(
            isPresented: isPresented,
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            icon: icon,
            onConfirm: onConfirm
        ))
    }

    /// Same, for an item (e.g. the book to delete): shown while `item` is set, cleared on either button.
    func confirmation<Item>(
        item: Binding<Item?>,
        title: @escaping (Item) -> String,
        message: String,
        confirmTitle: String,
        icon: String = "ph-trash",
        onConfirm: @escaping (Item) -> Void
    ) -> some View {
        modifier(ItemConfirmationModifier(
            item: item,
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            icon: icon,
            onConfirm: onConfirm
        ))
    }
}

private struct ConfirmationModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let confirmTitle: String
    let icon: String
    let onConfirm: () -> Void

    /// Follows `isPresented`, but changes without the cover's slide animation (the card animates itself).
    @State private var coverShown = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $coverShown) {
                ConfirmationCard(
                    title: title,
                    message: message,
                    confirmTitle: confirmTitle,
                    icon: icon,
                    onConfirm: {
                        isPresented = false
                        onConfirm()
                    },
                    onCancel: { isPresented = false }
                )
                .presentationBackground(.clear)
            }
            .onChange(of: isPresented, initial: true) { _, shown in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { coverShown = shown }
            }
    }
}

private struct ItemConfirmationModifier<Item>: ViewModifier {
    @Binding var item: Item?
    let title: (Item) -> String
    let message: String
    let confirmTitle: String
    let icon: String
    let onConfirm: (Item) -> Void

    /// The item being asked about, kept while the card animates out after `item` is cleared.
    @State private var shownItem: Item?
    @State private var coverShown = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $coverShown) {
                if let shownItem {
                    ConfirmationCard(
                        title: title(shownItem),
                        message: message,
                        confirmTitle: confirmTitle,
                        icon: icon,
                        onConfirm: {
                            item = nil
                            onConfirm(shownItem)
                        },
                        onCancel: { item = nil }
                    )
                    .presentationBackground(.clear)
                }
            }
            .onChange(of: item != nil, initial: true) { _, shown in
                if shown { shownItem = item }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { coverShown = shown }
            }
    }
}
