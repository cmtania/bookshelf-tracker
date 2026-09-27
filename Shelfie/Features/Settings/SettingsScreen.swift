import SwiftData
import SwiftUI

struct SettingsScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(UnlockGate.self) private var gate

    // Defaults must match Prefs.
    @AppStorage(Prefs.remindersEnabledKey) private var remindersEnabled = true
    @AppStorage(Prefs.reminderMinutesKey) private var reminderMinutes = Prefs.defaultReminderMinutes
    @AppStorage(Prefs.streakAlertEnabledKey) private var streakAlertEnabled = true

    @State private var showingPaywall = false

    // Categories are managed in their own tab (CategoriesScreen).
    var body: some View {
        NavigationStack {
            List {
                unlockSection
                appearanceSection
                remindersSection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
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
