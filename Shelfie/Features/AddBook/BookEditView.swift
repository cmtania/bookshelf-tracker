import SwiftData
import SwiftUI

/// Add a new book (book == nil) or edit an existing one.
struct BookEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \BookCategory.sortIndex) private var categories: [BookCategory]
    @Query private var allBooks: [Book]

    let book: Book?
    let initialCategory: BookCategory?
    /// Called when the user confirms deleting; the presenter deletes after dismissing.
    var onDelete: (() -> Void)?

    @State private var title = ""
    @State private var author = ""
    @State private var totalPages: Int?
    @State private var currentPage: Int?
    @State private var categoryID: UUID?
    @State private var status: ReadingStatus = .reading
    @State private var colorHex = Palette.colors[5]
    @State private var dailyGoal: Int?
    @State private var remindersOn = true
    @State private var confirmingDelete = false
    @State private var loaded = false

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        !trimmedTitle.isEmpty && (totalPages ?? 0) > 0 && categoryID != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    TextField("Author", text: $author)
                        .textInputAutocapitalization(.words)
                    NumberField("Number of pages", value: $totalPages)
                    if book != nil {
                        NumberField("Current page", value: $currentPage)
                    }
                }

                Section("Shelf") {
                    Picker("Category", selection: $categoryID) {
                        ForEach(categories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                    Picker("Status", selection: $status) {
                        ForEach(ReadingStatus.allCases) { status in
                            Label(status.label, image: status.symbol).tag(status)
                        }
                    }
                }

                Section("Spine color") {
                    ColorSwatchPicker(selection: $colorHex)
                }

                Section {
                    NumberField("Daily goal in pages (optional)", value: $dailyGoal, maxDigits: 4)
                    Toggle("Reminders for this book", isOn: $remindersOn)
                } header: {
                    Text("Goal & reminders")
                } footer: {
                    Text("Daily reminders and streak alerts use the times in Settings, while the book is marked Reading.")
                }

                if book != nil {
                    Section {
                        Button("Delete book", role: .destructive) {
                            confirmingDelete = true
                        }
                    }
                }
            }
            .navigationTitle(book == nil ? "Add book" : "Edit book")
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
            .confirmation(
                "Delete “\(book?.title ?? "this book")”?",
                isPresented: $confirmingDelete,
                message: BookDeletion.confirmationMessage,
                confirmTitle: "Delete book"
            ) {
                onDelete?()
                dismiss()
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let book {
            title = book.title
            author = book.author
            totalPages = book.totalPages
            currentPage = book.currentPage
            categoryID = book.category?.id
            status = book.status
            colorHex = book.spineColorHex
            dailyGoal = book.dailyGoalPages
            remindersOn = book.remindersOn
        } else {
            categoryID = initialCategory?.id ?? categories.first?.id
            colorHex = Palette.colors.randomElement() ?? Palette.colors[5]
        }
    }

    private func save() {
        let pages = max(1, totalPages ?? 1)
        let target: Book
        if let book {
            target = book
        } else {
            target = Book()
            target.shelfOrder = (allBooks.map(\.shelfOrder).max() ?? -1) + 1
            context.insert(target)
        }
        target.title = trimmedTitle
        target.author = author.trimmingCharacters(in: .whitespacesAndNewlines)
        target.totalPages = pages
        target.currentPage = min(max(0, currentPage ?? target.currentPage), pages)
        target.category = categories.first { $0.id == categoryID }
        target.spineColorHex = colorHex
        target.dailyGoalPages = dailyGoal.flatMap { $0 > 0 ? $0 : nil }
        target.remindersOn = remindersOn
        if book == nil || target.status != status {
            target.setStatus(status)
        }
        try? context.save()

        let wantsReminders = remindersOn && status == .reading
        Task {
            if wantsReminders {
                await ReminderScheduler.requestAuthorization()
            }
            await ReminderScheduler.reschedule(context: context)
        }
        dismiss()
    }
}
