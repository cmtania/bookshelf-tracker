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
    @State private var showingAbout = false
    @State private var managingSubscription = false
    @State private var confirmingReset = false

    // Categories are managed in their own tab (CategoriesScreen).
    var body: some View {
        NavigationStack {
            List {
                unlockSection
                remindersSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAbout) {
                AboutSheet()
            }
            .sheet(isPresented: $confirmingReset) {
                ResetDataSheet {
                    Task { await DataReset.eraseLibrary(context) }
                }
            }
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
            switch gate.activePlan {
            case .lifetime:
                Label("Shelfie Pro · Lifetime. Thank you!", image: "ph-seal-check-fill")
                    .foregroundStyle(Color.accentColor)
                if gate.hasMonthlySubscription {
                    // Bought Lifetime while subscribed: the subscription keeps renewing until cancelled.
                    Button {
                        managingSubscription = true
                    } label: {
                        Label("You still have a monthly subscription. Cancel it here.", image: "ph-warning-circle")
                    }
                }
            case .monthly:
                Label("Shelfie Pro · Monthly", image: "ph-seal-check-fill")
                    .foregroundStyle(Color.accentColor)
                Button {
                    showingPaywall = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Switch to Lifetime")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Pay once and stop paying monthly")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let price = gate.lifetime?.displayPrice {
                            Text(price)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                Button("Manage subscription") {
                    managingSubscription = true
                }
            case nil:
                Button {
                    showingPaywall = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Get Shelfie Pro")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Unlimited books · all 10 shelves · room colors")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let price = gate.lifetime?.displayPrice {
                            Text("\(price) once")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                Button("Restore purchase") {
                    Task { await gate.restore() }
                }
            }
        }
        .manageSubscriptionsSheet(isPresented: $managingSubscription)
    }

    // Room colors live on the Bookshelf tab (the paintbrush), so they aren't repeated here.

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

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                confirmingReset = true
            } label: {
                Label("Reset all data", image: "ph-trash")
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Start over with an empty bookcase. Your library is stored only on this iPhone, so it can’t be recovered afterwards.")
        }
    }

    /// One row; help, legal pages, support and the version are in the About sheet.
    private var aboutSection: some View {
        Section {
            Button {
                showingAbout = true
            } label: {
                HStack(spacing: 12) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30)
                        .accessibilityHidden(true)
                    Text("About Shelfie")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image("ph-caret-right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
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

/// Small "PRO" tag for features included in Shelfie Pro.
struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(.white)
            .background(Capsule().fill(Color.accentColor))
            .accessibilityLabel("Included with Shelfie Pro")
    }
}

enum AppLinks {
    static let privacy = URL(string: "https://cmtania.github.io/bookshelf-tracker-docs/privacy.html")!
    static let support = URL(string: "https://cmtania.github.io/bookshelf-tracker-docs/support.html")!
    /// Shelfie's own Terms of Service page (the paywall links Apple's EULA, `terms`).
    static let termsOfService = URL(string: "https://cmtania.github.io/bookshelf-tracker-docs/terms.html")!
    /// Apple's standard EULA ("Terms of Use"), which App Review expects next to subscriptions.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let supportEmail = URL(string: "mailto:tania.dev.ph@gmail.com?subject=Shelfie%20support")!
}
