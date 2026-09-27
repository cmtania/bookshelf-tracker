import Foundation
import SwiftData

/// Deleting a book, from anywhere in the app. Its reading sessions and notes go with it
/// (cascade rules on `Book`), and reminders are re-planned without it.
@MainActor
enum BookDeletion {
    static func delete(_ book: Book, in context: ModelContext) async {
        context.delete(book)
        try? context.save()
        await ReminderScheduler.reschedule(context: context)
    }

    static let confirmationMessage = "Its notes and reading sessions are deleted too. This can’t be undone."
}
