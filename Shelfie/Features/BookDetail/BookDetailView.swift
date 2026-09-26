import SwiftData
import SwiftUI

struct BookDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var book: Book

    @State private var logging = false
    @State private var editing = false
    @State private var addingNote = false
    @State private var editingNote: BookNote?
    @State private var pendingDelete = false

    private let streaks = StreakCalculator()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                }
                Section {
                    progressRow
                    streakRow
                }
                Section {
                    Button {
                        logging = true
                    } label: {
                        Label("Log reading", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.glassProminent)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .disabled(book.status == .finished && book.currentPage >= book.totalPages)
                }
                notesSection
                sessionsSection
            }
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit") { editing = true }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $logging) {
                LogReadingSheet(book: book)
            }
            .sheet(isPresented: $addingNote) {
                NoteEditSheet(book: book, note: nil)
            }
            .sheet(item: $editingNote) { note in
                NoteEditSheet(book: book, note: note)
            }
            .sheet(isPresented: $editing, onDismiss: deleteIfRequested) {
                BookEditView(book: book, initialCategory: nil, onDelete: { pendingDelete = true })
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: book.spineColorHex))
                .frame(width: 34, height: 54)
            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(.headline)
                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let category = book.category {
                    Text(category.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Menu {
                ForEach(ReadingStatus.allCases) { status in
                    Button {
                        book.setStatus(status)
                        saveAndReschedule()
                    } label: {
                        Label(status.label, systemImage: status.symbol)
                    }
                }
            } label: {
                Label(book.status.label, systemImage: book.status.symbol)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
            }
        }
        .padding(.vertical, 4)
    }

    private var progressRow: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: book.progress)
                    .stroke(Color(hex: book.spineColorHex), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int((book.progress * 100).rounded()))%")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(width: 68, height: 68)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(Int((book.progress * 100).rounded())) percent read")

            VStack(alignment: .leading, spacing: 4) {
                Text("Page \(book.currentPage) of \(book.totalPages)")
                    .font(.headline)
                Text("\(max(0, book.totalPages - book.currentPage)) pages left")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let goal = book.dailyGoalPages {
                    Text("Today \(pagesToday) / \(goal) pages")
                        .font(.subheadline)
                        .foregroundStyle(pagesToday >= goal ? Color.green : Color.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var streakRow: some View {
        let dates = book.sessionDates
        let current = streaks.currentStreak(dates)
        let best = streaks.bestStreak(dates)
        let readToday = streaks.readToday(dates)
        return HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(current > 0 ? Color.orange : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(current)-day streak")
                    .font(.headline)
                Text(readToday ? "Read today ✓" : (current > 0 ? "Read today to keep it going" : "Log a session to start one"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(best)")
                    .font(.headline)
                Text("best")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

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
                Label("Add note", systemImage: "square.and.pencil")
            }
        }
    }

    private var sessionsSection: some View {
        Section("Reading sessions") {
            let sessions = book.sortedSessions
            if sessions.isEmpty {
                Text("No sessions yet. Tap Log reading after you read.")
                    .foregroundStyle(.secondary)
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
                            .font(.subheadline.weight(.semibold))
                        if let minutes = session.minutes {
                            Text("\(minutes) min")
                                .font(.caption)
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

    /// Runs after the edit sheet closes. Dismiss this sheet first, then delete, so no view
    /// reads the book after it's gone.
    private func deleteIfRequested() {
        guard pendingDelete else { return }
        pendingDelete = false
        let doomed = self.book
        let modelContext = self.context
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            modelContext.delete(doomed)
            try? modelContext.save()
            await ReminderScheduler.reschedule(context: modelContext)
        }
    }
}
