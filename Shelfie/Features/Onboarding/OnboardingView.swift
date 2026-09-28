import SwiftData
import SwiftUI

/// First launch (and after Reset all data): four short pages. Welcome, name your three
/// shelves, how logging and streaks work, and reminders. Skippable at every step, no paywall.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BookCategory.sortIndex) private var categories: [BookCategory]
    @AppStorage(Prefs.remindersEnabledKey) private var remindersEnabled = true
    @AppStorage(Prefs.reminderMinutesKey) private var reminderMinutes = Prefs.defaultReminderMinutes

    /// Called when the user finishes or skips.
    let onFinish: () -> Void

    @State private var page = 0
    @State private var names = ["", "", ""]
    @State private var loadedNames = false
    @State private var reminderState: ReminderState = .notAsked
    @FocusState private var focusedField: Int?

    private enum ReminderState {
        case notAsked, allowed, denied
    }

    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pageCount - 1 {
                    Button("Skip") { finish() }
                        .font(.body.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 52)

            TabView(selection: $page) {
                welcomePage.tag(0)
                shelvesPage.tag(1)
                habitPage.tag(2)
                remindersPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageDots
                .padding(.top, 8)

            Button {
                advance()
            } label: {
                Text(page == pageCount - 1 ? "Start reading" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 36)
            }
            .buttonStyle(.glassProminent)
            // As wide as the pages on iPad, not the whole screen.
            .frame(maxWidth: 480)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.16), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        )
        .onAppear(perform: loadNames)
        .onChange(of: categories.count) { _, _ in loadNames() }
        .onChange(of: page) { _, _ in
            focusedField = nil
            saveNames()
        }
    }

    // MARK: Pages

    private var welcomePage: some View {
        pageLayout {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 150)
                .shadow(color: .black.opacity(0.15), radius: 16, y: 10)
                .accessibilityHidden(true)
            Text("Welcome to Shelfie")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Your reading, on a real 3D bookshelf. Let’s set it up. It takes less than a minute.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var shelvesPage: some View {
        pageLayout {
            MiniShelf(colors: categories.prefix(3).map(\.colorHex))
                .frame(height: 150)
                .accessibilityHidden(true)
            Text("Name your shelves")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Each category is one compartment of your bookcase. Start with three. You can rename them anytime.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                ForEach(0..<min(3, categories.count), id: \.self) { index in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: categories[index].colorHex))
                            .frame(width: 14, height: 14)
                        TextField(placeholder(index), text: $names[index])
                            .textInputAutocapitalization(.words)
                            .submitLabel(index < 2 ? .next : .done)
                            .focused($focusedField, equals: index)
                            .onSubmit { focusedField = index < 2 ? index + 1 : nil }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                }
            }
            .padding(.top, 4)
        }
    }

    private var habitPage: some View {
        pageLayout {
            Image("ph-flame-fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .frame(width: 120, height: 120)
                .background(Circle().fill(Color.orange.opacity(0.14)))
                .accessibilityHidden(true)
            Text("Log it, keep the streak")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 18) {
                habitRow("ph-plus-circle-fill", "Log in seconds", "Tap a book, then Log reading. Type the page you’re on and you’re done.")
                habitRow("ph-flame-fill", "A streak for every book", "Read a little each day to keep each book’s streak, and your overall one, going.")
                habitRow("ph-calendar-dots", "See your week", "The calendar shows a dot for every book you read, day by day.")
            }
            .padding(.top, 4)
        }
    }

    private var remindersPage: some View {
        pageLayout {
            Image("ph-bell-ringing-fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .frame(width: 120, height: 120)
                .background(Circle().fill(Color.accentColor.opacity(0.14)))
                .accessibilityHidden(true)
            Text("A nudge at reading time")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("One daily reminder at the time you choose, and an evening heads-up if a streak is about to slip. Nothing else.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            DatePicker("Remind me at", selection: reminderTime, displayedComponents: .hourAndMinute)
                .padding(.horizontal, 16)
                .frame(minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))

            switch reminderState {
            case .notAsked:
                Button {
                    turnOnReminders()
                } label: {
                    Label("Turn on reminders", image: "ph-bell-fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.glass)
                Text("You can change this anytime in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .allowed:
                Label("Reminders are on", image: "ph-check-circle-fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            case .denied:
                Text("Notifications are off for Shelfie. You can allow them later in iOS Settings → Notifications → Shelfie.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: Building blocks

    /// Page layout: content centred, scrollable so large text and the keyboard never clip it.
    private func pageLayout<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                content()
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
    }

    private func habitRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(symbol)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == page ? 22 : 8, height: 8)
            }
        }
        .animation(.snappy, value: page)
        .accessibilityElement()
        .accessibilityLabel("Page \(page + 1) of \(pageCount)")
    }

    private func placeholder(_ index: Int) -> String {
        ["e.g. Novels", "e.g. Study", "e.g. Comics"][index]
    }

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

    // MARK: Actions

    private func loadNames() {
        guard !loadedNames, !categories.isEmpty else { return }
        loadedNames = true
        for (index, category) in categories.prefix(3).enumerated() {
            // Leave the field empty (showing the placeholder) while it still has its starter name.
            names[index] = category.name.hasPrefix("Shelf ") ? "" : category.name
        }
    }

    private func saveNames() {
        for (index, category) in categories.prefix(3).enumerated() {
            let name = names[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty, name != category.name {
                category.name = name
            }
        }
        try? context.save()
    }

    private func turnOnReminders() {
        Task {
            let allowed = await ReminderScheduler.requestAuthorization()
            remindersEnabled = allowed
            reminderState = allowed ? .allowed : .denied
        }
    }

    private func advance() {
        if page < pageCount - 1 {
            withAnimation(.snappy) { page += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        saveNames()
        Task { await ReminderScheduler.reschedule(context: context) }
        onFinish()
    }
}

/// A small flat bookcase with three compartments in the starter shelf colours.
private struct MiniShelf: View {
    let colors: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(colors.enumerated()), id: \.offset) { index, hex in
                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(0..<4, id: \.self) { book in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: hex).opacity(1 - Double(book) * 0.18))
                                .frame(width: 12, height: CGFloat(52 + ((index + book) % 3) * 10))
                        }
                    }
                    .frame(width: 84, height: 96, alignment: .bottom)
                    .padding(.bottom, 4)
                    .background(Color(hex: "#E6E3DC"))
                    Rectangle()
                        .fill(Color(hex: "#F1EFEA"))
                        .frame(height: 8)
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: "#F1EFEA")))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
    }
}
