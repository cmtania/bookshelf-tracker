import SwiftData
import SwiftUI

struct LogReadingSheet: View {
    enum Mode: String, CaseIterable, Identifiable {
        case pageReached = "Page I'm on"
        case pagesRead = "Pages read"

        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let book: Book

    @State private var mode: Mode = .pageReached
    @State private var value: Int?
    @State private var minutes: Int?
    @State private var date = Date()
    @State private var markFinished = true
    @FocusState private var valueFocused: Bool

    private var newPage: Int {
        let entered = max(0, value ?? 0)
        switch mode {
        case .pageReached:
            return min(book.totalPages, entered)
        case .pagesRead:
            return min(book.totalPages, book.currentPage + entered)
        }
    }

    private var pagesGained: Int { max(0, newPage - book.currentPage) }

    /// A session needs progress or time spent (re-reading earlier pages still counts with minutes).
    private var isValid: Bool { pagesGained > 0 || (minutes ?? 0) > 0 }

    private var reachesEnd: Bool { newPage >= book.totalPages && book.status != .finished }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Log by", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    NumberField(mode == .pageReached ? "Page number" : "Pages read", value: $value)
                        .focused($valueFocused)
                } footer: {
                    if pagesGained > 0 {
                        Text("Page \(book.currentPage) → \(newPage) (+\(pagesGained) pages)")
                    } else {
                        Text("You're on page \(book.currentPage) of \(book.totalPages).")
                    }
                }

                Section {
                    NumberField("Minutes read (optional)", value: $minutes, maxDigits: 4)
                    DatePicker("When", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                }

                if reachesEnd {
                    Section {
                        Toggle("Mark as finished 🎉", isOn: $markFinished)
                    }
                }
            }
            .navigationTitle("Log reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear { valueFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let target = max(book.currentPage, newPage)
        let finishing = reachesEnd && markFinished
        let session = ReadingSession(date: date, fromPage: book.currentPage, toPage: target, minutes: minutes.flatMap { $0 > 0 ? $0 : nil })
        context.insert(session)
        session.book = book
        book.currentPage = target
        if book.status == .wantToRead {
            book.setStatus(.reading, now: date)
        }
        if finishing {
            book.setStatus(.finished, now: date)
        }
        try? context.save()
        Task { await ReminderScheduler.reschedule(context: context) }
        dismiss()
    }
}
