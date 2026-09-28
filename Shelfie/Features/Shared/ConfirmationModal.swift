import SwiftUI

// Confirmations for destructive actions (deleting a book or a category) use the system alert:
// centred on screen, with the message and both buttons inside it, like BuzzBee's Reset All Data.

extension View {
    /// Asks before a destructive action.
    func confirmation(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String,
        confirmTitle: String,
        onConfirm: @escaping () -> Void
    ) -> some View {
        alert(title, isPresented: isPresented) {
            Button("Cancel", role: .cancel) {}
            Button(confirmTitle, role: .destructive, action: onConfirm)
        } message: {
            Text(message)
        }
    }

    /// Same, for an item (e.g. the book to delete): shown while `item` is set.
    ///
    /// The item is usually a SwiftData model. It's cleared *before* the action runs, so nothing
    /// on screen reads it after it's deleted (reading a deleted model crashes the app).
    func confirmation<Item>(
        item: Binding<Item?>,
        title: @escaping (Item) -> String,
        message: String,
        confirmTitle: String,
        onConfirm: @escaping (Item) -> Void
    ) -> some View {
        alert(
            item.wrappedValue.map(title) ?? "",
            isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { if !$0 { item.wrappedValue = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {}
            Button(confirmTitle, role: .destructive) {
                guard let target = item.wrappedValue else { return }
                item.wrappedValue = nil
                onConfirm(target)
            }
        } message: {
            Text(message)
        }
    }
}
