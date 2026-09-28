import SwiftData
import SwiftUI

/// The "Log reading" screen, opened from the book shown up close on the shelf.
/// - The book on top (a small cover in its spine colour), then its progress and streak, with the
///   numbers bigger than their labels.
/// - **Log reading** is pinned to the bottom, within thumb reach.
/// - Saving a session is celebrated with a card, a bounce and a haptic: the moment people remember.
struct BookDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var book: Book

    @State private var logging = false
    @State private var addingNote = false
    @State private var editingNote: BookNote?
    /// Set by the Log reading sheet when it saves; shown once the sheet has gone.
    @State private var pendingCelebration: LoggedReading?
    @State private var celebration: LoggedReading?

    private let streaks = StreakCalculator()

    private var isComplete: Bool {
        book.status == .finished && book.currentPage >= book.totalPages
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                    progressRow
                    streakRow
                }
                notesSection
                sessionsSection
            }
            .navigationTitle("Log reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                logButton
            }
            .overlay(alignment: .top) {
                if let celebration {
                    ReadingCelebrationCard(logged: celebration) {
                        withAnimation(.snappy) { self.celebration = nil }
                    }
                    .padding(.top, 8)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .id(celebration.id)
                }
            }
            .sensoryFeedback(trigger: celebration?.id) { _, new in
                new == nil ? nil : .success
            }
            .sheet(isPresented: $logging, onDismiss: showPendingCelebration) {
                LogReadingSheet(book: book) { pendingCelebration = $0 }
            }
            .sheet(isPresented: $addingNote) {
                NoteEditSheet(book: book, note: nil)
            }
            .sheet(item: $editingNote) { note in
                NoteEditSheet(book: book, note: note)
            }
        }
    }

    private func showPendingCelebration() {
        guard let pending = pendingCelebration else { return }
        pendingCelebration = nil
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(duration: 0.5, bounce: 0.3)) {
            celebration = pending
        }
    }

    // MARK: Top

    private var header: some View {
        let spine = Color(hex: book.spineColorHex)
        return HStack(spacing: 16) {
            // A small cover in the spine colour, with a darker hinge and a shadow in the same hue.
            RoundedRectangle(cornerRadius: 6)
                .fill(spine)
                .overlay(alignment: .leading) {
                    Rectangle().fill(.black.opacity(0.18)).frame(width: 4)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(width: 48, height: 72)
                .shadow(color: spine.opacity(0.35), radius: 8, y: 4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.title3.bold())
                    .lineLimit(2)
                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Label(book.status.label, image: book.status.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var progressRow: some View {
        let percent = Int((book.progress * 100).rounded())
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: book.progress)
                    .stroke(Color(hex: book.spineColorHex), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(percent)%")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())
            }
            .frame(width: 72, height: 72)
            .animation(reduceMotion ? nil : .spring(duration: 0.8, bounce: 0.2), value: book.progress)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(percent) percent read")

            VStack(alignment: .leading, spacing: 4) {
                // The value leads; the label supports it.
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(book.currentPage)")
                        .font(.title2.bold().monospacedDigit())
                        .contentTransition(.numericText())
                    Text("of \(book.totalPages) pages")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("\(max(0, book.totalPages - book.currentPage)) pages left")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let goal = book.dailyGoalPages {
                    Label("Today \(pagesToday) / \(goal) pages", image: pagesToday >= goal ? "ph-check-circle-fill" : "ph-book-open")
                        .font(.subheadline)
                        .foregroundStyle(pagesToday >= goal ? Color.green : Color.secondary)
                }
            }
            .animation(reduceMotion ? nil : .snappy, value: book.currentPage)
        }
        .padding(.vertical, 8)
    }

    private var streakRow: some View {
        let dates = book.sessionDates
        let current = streaks.currentStreak(dates)
        let best = streaks.bestStreak(dates)
        let readToday = streaks.readToday(dates)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                statTile(value: current, label: "day streak", icon: "ph-flame-fill", tint: current > 0 ? .orange : .secondary)
                Divider().frame(height: 40)
                statTile(value: best, label: "best streak", icon: "ph-sparkle", tint: .secondary)
            }
            Label(
                readToday ? "Read today" : (current > 0 ? "Read today to keep it going" : "Log a session to start one"),
                image: readToday ? "ph-check-circle-fill" : "ph-clock"
            )
            .font(.subheadline)
            .foregroundStyle(readToday ? Color.green : Color.secondary)
        }
        .padding(.vertical, 8)
        .animation(reduceMotion ? nil : .snappy, value: current)
        .accessibilityElement(children: .combine)
    }

    private func statTile(value: Int, label: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(icon)
                    .font(.headline)
                    .foregroundStyle(tint)
                Text("\(value)")
                    .font(.title2.bold().monospacedDigit())
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var logButton: some View {
        Button {
            logging = true
        } label: {
            Label(isComplete ? "Finished" : "Log reading", image: isComplete ? "ph-seal-check-fill" : "ph-plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.glassProminent)
        .disabled(isComplete)
        .frame(maxWidth: 520)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: Notes and sessions

    private var notesSection: some View {
        Section("Notes") {
            ForEach(book.sortedNotes) { note in
                Button {
                    editingNote = note
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.text)
                            .lineLimit(4)
                            .foregroundStyle(.primary)
                        Text(noteCaption(note))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .onDelete { offsets in
                let notes = book.sortedNotes
                for index in offsets {
                    context.delete(notes[index])
                }
                try? context.save()
            }
            Button {
                addingNote = true
            } label: {
                Label("Add note", image: "ph-note-pencil")
            }
        }
    }

    private var sessionsSection: some View {
        Section("Reading sessions") {
            let sessions = book.sortedSessions
            if sessions.isEmpty {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No sessions yet")
                            .font(.subheadline.weight(.semibold))
                        Text("Your first one starts this book’s streak.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image("ph-flame-fill")
                        .foregroundStyle(.orange)
                }
                .padding(.vertical, 4)
            }
            ForEach(sessions) { session in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.date.formatted(date: .abbreviated, time: .shortened))
                        Text("p. \(session.fromPage) → \(session.toPage)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("+\(session.pagesRead) pages")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                        if let minutes = session.minutes {
                            Text("\(minutes) min")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    context.delete(sessions[index])
                }
                saveAndReschedule()
            }
        }
    }

    // MARK: Helpers

    private var pagesToday: Int {
        (book.sessions ?? [])
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.pagesRead }
    }

    private func noteCaption(_ note: BookNote) -> String {
        let date = note.createdAt.formatted(date: .abbreviated, time: .omitted)
        if let page = note.page {
            return "Page \(page) · \(date)"
        }
        return date
    }

    private func saveAndReschedule() {
        try? context.save()
        Task { await ReminderScheduler.reschedule(context: context) }
    }
}
