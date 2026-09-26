import SwiftData
import SwiftUI

@main
struct ShelfieApp: App {
    @State private var unlock = UnlockGate()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(unlock)
        }
        .modelContainer(for: [BookCategory.self, Book.self, ReadingSession.self, BookNote.self])
    }
}
