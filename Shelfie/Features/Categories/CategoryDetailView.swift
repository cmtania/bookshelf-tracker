import SwiftData
import SwiftUI

/// One category: its numbers, what's being read in it, all of its books, and edit / add / delete.
struct CategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(UnlockGate.self) private var gate
    @Query(sort: \BookCategory.sortIndex) private var categories: [BookCategory]
    @Query private var allBooks: [Book]

    let category: BookCategory

    @State private var editing = false
    @State private var addingBook = false
    @State private var showingPaywall = false
    @State private var readingBook: Book?
    @State private var confirmingDelete = false
    /// A book waiting for "Delete book?" to be confirmed.
    @State private var bookToDelete: Book?

    private var index: Int {
        categories.firstIndex { $0.id == category.id } ?? category.sortIndex
    }

    /// Reading first, then want to read, then finished; newest first within each.
    private var sortedBooks: [Book] {
        let order: [ReadingStatus: Int] = [.reading: 0, .wantToRead: 1, .finished: 2]
        return (category.books ?? []).sorted {
            let lhs = order[$0.status] ?? 3, rhs = order[$1.status] ?? 3
            return lhs != rhs ? lhs < rhs : $0.createdAt > $1.createdAt
        }
    }

    var body: some View {
        let stats = CategoryStats(category)
        let color = Color(hex: category.colorHex)
        List {
            Section {
                header(stats, color: color)
                statGrid(stats)
            }

            if !stats.nowReading.isEmpty {
                Section("Reading now") {
                    ForEach(stats.nowReading) { book in
                        Button { readingBook = book } label: { readingRow(book) }
                            .swipeActions { deleteAction(book) }
                            .contextMenu { bookMenu(book) }
                    }
                }
            }

            Section {
                if sortedBooks.isEmpty {
                    Text("No books in this category yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(sortedBooks) { book in
                    Button { readingBook = book } label: { bookRow(book) }
                        .swipeActions { deleteAction(book) }
                        .contextMenu { bookMenu(book) }
                }
                Button {
                    requestAddBook()
                } label: {
                    Label("Add a book here", systemImage: "plus")
                }
            } header: {
                Text("All books")
            }

            Section {
                Button("Delete category", role: .destructive) {
                    confirmingDelete = true
                }
                .disabled(stats.bookCount > 0)
            } footer: {
                if stats.bookCount > 0 {
                    Text("To delete this category, move or delete its books first.")
                }
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editing = true }
            }
        }
        .sheet(isPresented: $editing) {
            CategoryEditSheet(category: category)
        }
        .sheet(isPresented: $addingBook) {
            BookEditView(book: nil, initialCategory: category)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(item: $readingBook) { book in
            BookDetailView(book: book)
        }
        .confirmationDialog(
            "Delete “\(bookToDelete?.title ?? "this book")”?",
            isPresented: Binding(get: { bookToDelete != nil }, set: { if !$0 { bookToDelete = nil } }),
            titleVisibility: .visible,
            presenting: bookToDelete
        ) { book in
            Button("Delete book", role: .destructive) {
                Task { await BookDeletion.delete(book, in: context) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text(BookDeletion.confirmationMessage)
        }
        .confirmationDialog("Delete “\(category.name)”?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete category", role: .destructive) { deleteCategory() }
        } message: {
            Text("Its compartment on the bookcase becomes free.")
        }
    }

    // MARK: Header

    private func header(_ stats: CategoryStats, color: Color) -> some View {
        HStack(spacing: 14) {
            // A little stack of spines in the category's colour.
            HStack(alignment: .bottom, spacing: 3) {
                RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 38)
                RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.75)).frame(width: 12, height: 48)
                RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.5)).frame(width: 12, height: 32)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.title3.bold())
                Text(CategoryStats.position(ofIndex: index))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if stats.streak > 0 {
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    Text("\(stats.streak)")
                        .font(.headline)
                    Text("days")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(stats.streak)-day streak")
            }
        }
        .padding(.vertical, 6)
    }

    private func statGrid(_ stats: CategoryStats) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                tile("\(stats.bookCount)", "books")
                tile("\(stats.reading)", "reading")
                tile("\(stats.finished)", "finished")
                tile("\(stats.wantToRead)", "to read")
            }
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: stats.progress)
                    .tint(Color(hex: category.colorHex))
                HStack {
                    Text("\(stats.pagesRead.formatted()) of \(stats.totalPages.formatted()) pages read")
                    Spacer()
                    Text("\(stats.pagesThisWeek.formatted()) this week")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if let last = stats.lastRead {
                Text("Last read \(last.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
    }

    private func tile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Rows

    private func deleteAction(_ book: Book) -> some View {
        Button(role: .destructive) {
            bookToDelete = book
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func bookMenu(_ book: Book) -> some View {
        Button {
            readingBook = book
        } label: {
            Label("Open", systemImage: "book")
        }
        Button(role: .destructive) {
            bookToDelete = book
        } label: {
            Label("Delete book", systemImage: "trash")
        }
    }

    private func readingRow(_ book: Book) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(book.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                let streak = StreakCalculator().currentStreak(book.sessionDates)
                if streak > 0 {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            ProgressView(value: book.progress)
                .tint(Color(hex: book.spineColorHex))
            Text("Page \(book.currentPage) of \(book.totalPages) · \(max(0, book.totalPages - book.currentPage)) left")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func bookRow(_ book: Book) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: book.spineColorHex))
                .frame(width: 8, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(book.author.isEmpty ? "\(book.totalPages) pages" : "\(book.author) · \(book.totalPages) pages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Label(book.status.label, systemImage: book.status.symbol)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
        }
    }

    // MARK: Actions

    private func requestAddBook() {
        if gate.canAddBook(currentCount: allBooks.count) {
            addingBook = true
        } else {
            showingPaywall = true
        }
    }

    /// Leave the screen first, then delete and renumber the other compartments, so nothing
    /// on screen reads the category after it's gone.
    private func deleteCategory() {
        let doomed = category
        let modelContext = context
        let others = categories.filter { $0.id != category.id }
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            modelContext.delete(doomed)
            for (index, other) in others.enumerated() {
                other.sortIndex = index
            }
            try? modelContext.save()
        }
    }
}
