import SwiftData
import SwiftUI

struct SettingsScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(UnlockGate.self) private var gate
    @Query(sort: \BookCategory.sortIndex) private var categories: [BookCategory]

    // Defaults must match Prefs.
    @AppStorage(Prefs.remindersEnabledKey) private var remindersEnabled = true
    @AppStorage(Prefs.reminderMinutesKey) private var reminderMinutes = Prefs.defaultReminderMinutes
    @AppStorage(Prefs.streakAlertEnabledKey) private var streakAlertEnabled = true

    @State private var editingCategory: BookCategory?
    @State private var addingCategory = false
    @State private var showingPaywall = false
    @State private var blockedDelete: BookCategory?

    var body: some View {
        NavigationStack {
            List {
                unlockSection
                appearanceSection
                categoriesSection
                remindersSection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(item: $editingCategory) { category in
                CategoryEditSheet(category: category)
            }
            .sheet(isPresented: $addingCategory) {
                CategoryEditSheet(category: nil)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .alert(
                "This category still has books",
                isPresented: Binding(get: { blockedDelete != nil }, set: { if !$0 { blockedDelete = nil } }),
                presenting: blockedDelete
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { category in
                Text("Move or delete the \(category.bookCount) books in “\(category.name)” first.")
            }
            .onChange(of: remindersEnabled) { _, enabled in
                reschedule(requestPermission: enabled)
            }
            .onChange(of: reminderMinutes) { _, _ in
                reschedule(requestPermission: false)
            }
            .onChange(of: streakAlertEnabled) { _, enabled in
                reschedule(requestPermission: enabled)
            }
        }
    }

    // MARK: Sections

    private var unlockSection: some View {
        Section {
            if gate.isUnlocked {
                Label("Shelfie is unlocked. Thank you!", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Color.accentColor)
            } else {
                Button {
                    showingPaywall = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unlock Shelfie")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Unlimited books · all 10 shelves · room colors · pay once")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let price = gate.product?.displayPrice {
                            Text(price)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                Button("Restore purchase") {
                    Task { await gate.restore() }
                }
            }
        }
    }

    /// Room colors are part of the one-time Unlock.
    private var appearanceSection: some View {
        Section("Appearance") {
            if gate.isUnlocked {
                NavigationLink {
                    RoomThemeEditor()
                        .navigationTitle("Room colors")
                } label: {
                    Label("Room colors", systemImage: "paintbrush.fill")
                }
            } else {
                Button {
                    showingPaywall = true
                } label: {
                    HStack {
                        Label("Room colors", systemImage: "paintbrush.fill")
                            .foregroundStyle(.primary)
                        Spacer()
                        ProBadge()
                    }
                }
            }
        }
    }

    private var categoriesSection: some View {
        Section {
            ForEach(categories) { category in
                Button {
                    editingCategory = category
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: category.colorHex))
                            .frame(width: 14, height: 14)
                        Text(category.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(category.bookCount)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onMove(perform: moveCategories)
            .onDelete(perform: deleteCategories)

            if categories.count < UnlockGate.maxCategories {
                Button {
                    if gate.canAddCategory(currentCount: categories.count) {
                        addingCategory = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    Label("Add category", systemImage: "plus")
                }
            }
        } header: {
            HStack {
                Text("Categories")
                Spacer()
                // Reorder / delete categories; lives on the section it edits.
                EditButton()
                    .font(.subheadline.weight(.semibold))
                    .textCase(nil)
            }
        } footer: {
            Text("Each category is one compartment of your bookcase, in this order from the top left (up to 10).")
        }
    }

    private var remindersSection: some View {
        Section {
            Toggle("Daily reminder", isOn: $remindersEnabled)
            if remindersEnabled {
                DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
            }
            Toggle("Streak at risk alert", isOn: $streakAlertEnabled)
        } header: {
            Text("Reminders")
        } footer: {
            Text("The streak alert comes at 8 PM when a book you're reading has a streak but no reading logged that day.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            Link("Privacy policy", destination: AppLinks.privacy)
            LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
        }
    }

    // MARK: Actions

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderMinutes = (parts.hour ?? 19) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var reordered = categories
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, category) in reordered.enumerated() {
            category.sortIndex = index
        }
        try? context.save()
    }

    private func deleteCategories(at offsets: IndexSet) {
        var remaining = categories
        for index in offsets.sorted(by: >) {
            let category = categories[index]
            if category.bookCount > 0 {
                blockedDelete = category
                continue
            }
            remaining.remove(at: index)
            context.delete(category)
        }
        for (index, category) in remaining.enumerated() {
            category.sortIndex = index
        }
        try? context.save()
    }

    private func reschedule(requestPermission: Bool) {
        Task {
            if requestPermission {
                await ReminderScheduler.requestAuthorization()
            }
            await ReminderScheduler.reschedule(context: context)
        }
    }
}

/// Small "PRO" tag for features included in the Unlock.
struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(.white)
            .background(Capsule().fill(Color.accentColor))
            .accessibilityLabel("Included with Unlock")
    }
}

enum AppLinks {
    static let privacy = URL(string: "https://github.com/cmtania/bookshelf-tracker/blob/main/PRIVACY.md")!
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
