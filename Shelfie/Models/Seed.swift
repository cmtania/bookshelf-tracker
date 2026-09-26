import Foundation
import SwiftData

enum Seed {
    /// Adds the three free categories on first launch with neutral names, so the user
    /// organises the shelf their own way (rename from the shelf's pencil button or Settings).
    static func ifNeeded(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Prefs.didSeedKey) else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<BookCategory>())) ?? 0
        if existing == 0 {
            let starters = [("Shelf 1", Palette.colors[5]), ("Shelf 2", Palette.colors[4]), ("Shelf 3", Palette.colors[2])]
            for (index, starter) in starters.enumerated() {
                context.insert(BookCategory(name: starter.0, colorHex: starter.1, sortIndex: index))
            }
            try? context.save()
        }
        defaults.set(true, forKey: Prefs.didSeedKey)
    }
}
