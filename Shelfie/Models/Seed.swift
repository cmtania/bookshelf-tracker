import Foundation
import SwiftData

enum Seed {
    /// Adds the three free categories on first launch with neutral names, so the user
    /// organises the shelf their own way (named in onboarding, or later from the Categories tab).
    static func ifNeeded(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Prefs.didSeedKey) else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<BookCategory>())) ?? 0
        if existing == 0 {
            insertStarterCategories(context)
        }
        defaults.set(true, forKey: Prefs.didSeedKey)
    }

    static func insertStarterCategories(_ context: ModelContext) {
        let starters = [("Shelf 1", Palette.colors[5]), ("Shelf 2", Palette.colors[4]), ("Shelf 3", Palette.colors[2])]
        for (index, starter) in starters.enumerated() {
            context.insert(BookCategory(name: starter.0, colorHex: starter.1, sortIndex: index))
        }
        try? context.save()
    }
}

enum DataReset {
    /// Deletes every book, reading session, note and category, then puts back the three
    /// starter shelves and shows onboarding again. Settings (reminder time, room colors)
    /// and the Shelfie Pro purchase are untouched; purchases live with Apple.
    @MainActor
    static func eraseLibrary(_ context: ModelContext) async {
        // One model at a time, children first, so no relationship points at a deleted object.
        for session in (try? context.fetch(FetchDescriptor<ReadingSession>())) ?? [] { context.delete(session) }
        for note in (try? context.fetch(FetchDescriptor<BookNote>())) ?? [] { context.delete(note) }
        for book in (try? context.fetch(FetchDescriptor<Book>())) ?? [] { context.delete(book) }
        for category in (try? context.fetch(FetchDescriptor<BookCategory>())) ?? [] { context.delete(category) }
        try? context.save()

        Seed.insertStarterCategories(context)
        UserDefaults.standard.set(false, forKey: Prefs.onboardingDoneKey)
        // No books are left, so this clears every pending reminder.
        await ReminderScheduler.reschedule(context: context)
    }
}
