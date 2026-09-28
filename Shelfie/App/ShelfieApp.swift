import SwiftData
import SwiftUI

@main
struct ShelfieApp: App {
    @State private var unlock = UnlockGate()
    @AppStorage(Prefs.appearanceKey) private var appearance = AppAppearance.system

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(unlock)
                // Settings > Appearance; applies to every screen and sheet.
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(for: [BookCategory.self, Book.self, ReadingSession.self, BookNote.self])
    }
}
