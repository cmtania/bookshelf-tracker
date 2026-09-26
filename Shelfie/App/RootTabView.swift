import SwiftData
import SwiftUI

struct RootTabView: View {
    enum TabID: Hashable {
        case shelf, calendar, settings
    }

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: TabID = .shelf

    var body: some View {
        TabView(selection: $tab) {
            Tab("Bookshelf", systemImage: "books.vertical.fill", value: .shelf) {
                BookshelfScreen()
            }
            Tab("Calendar", systemImage: "calendar", value: .calendar) {
                CalendarScreen()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                SettingsScreen()
            }
        }
        .task {
            Seed.ifNeeded(context)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await ReminderScheduler.reschedule(context: context) }
            }
        }
    }
}
