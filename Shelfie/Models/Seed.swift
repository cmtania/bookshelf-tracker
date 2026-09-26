import Foundation
import SwiftData

enum Seed {
    /// Adds three starter categories on first launch so the bookcase isn't empty.
    static func ifNeeded(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Prefs.didSeedKey) else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<BookCategory>())) ?? 0
        if existing == 0 {
            let starters = [("Fiction", Palette.colors[5]), ("Non-fiction", Palette.colors[4]), ("Learning", Palette.colors[2])]
            for (index, starter) in starters.enumerated() {
                context.insert(BookCategory(name: starter.0, colorHex: starter.1, sortIndex: index))
            }
            try? context.save()
        }
        defaults.set(true, forKey: Prefs.didSeedKey)
    }
}
