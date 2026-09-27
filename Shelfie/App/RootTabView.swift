import SwiftData
import SwiftUI

struct RootTabView: View {
    enum TabID: Hashable {
        case shelf, categories, calendar, settings
    }

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(UnlockGate.self) private var gate
    @AppStorage(Prefs.onboardingDoneKey) private var onboardingDone = false
    @State private var tab: TabID = .shelf

    var body: some View {
        TabView(selection: $tab) {
            Tab("Bookshelf", systemImage: "books.vertical.fill", value: .shelf) {
                BookshelfScreen()
            }
            Tab("Categories", systemImage: "square.grid.2x2.fill", value: .categories) {
                CategoriesScreen()
            }
            Tab("Calendar", systemImage: "calendar", value: .calendar) {
                CalendarScreen()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                SettingsScreen()
            }
        }
        // The launch screen's logo, handed over smoothly and faded into the bookshelf.
        .splashOnLaunch()
        .task {
            Seed.ifNeeded(context)
        }
        // First launch, and again after Reset all data.
        .fullScreenCover(isPresented: Binding(get: { !onboardingDone }, set: { if !$0 { onboardingDone = true } })) {
            OnboardingView {
                onboardingDone = true
                tab = .shelf
            }
            .interactiveDismissDisabled()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await ReminderScheduler.reschedule(context: context) }
                // Picks up a monthly subscription that renewed or ran out while the app was closed.
                Task { await gate.refresh() }
            }
        }
    }
}
