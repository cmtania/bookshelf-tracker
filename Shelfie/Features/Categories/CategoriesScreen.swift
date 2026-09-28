import SwiftData
import SwiftUI

/// The Categories tab: one card per category (its compartment on the bookcase) with the numbers
/// that matter, plus add, reorder and delete. Tap a card for the category's books.
struct CategoriesScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(UnlockGate.self) private var gate
    @Query(sort: \BookCategory.sortIndex) private var categories: [BookCategory]
    @Query private var books: [Book]

    @State private var addingCategory = false
    @State private var showingPaywall = false
    @State private var blockedDelete: BookCategory?

    var body: some View {
        NavigationStack {
            List {
                if !categories.isEmpty {
                    Section {
                        summary
                    }
                }

                Section {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                        NavigationLink {
                            CategoryDetailView(category: category)
                        } label: {
                            CategoryCard(category: category, index: index)
                        }
                    }
                    .onMove(perform: moveCategories)
                    .onDelete(perform: deleteCategories)
                } footer: {
                    Text(footerText)
                }
            }
            .navigationTitle("Categories")
            .overlay {
                if categories.isEmpty {
                    ContentUnavailableView {
                        Label("No categories yet", image: "ph-squares-four")
                    } description: {
                        Text("Each category is one compartment of your bookcase.")
                    } actions: {
                        Button("Add category") { requestAddCategory() }
                            .buttonStyle(.glassProminent)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !categories.isEmpty { EditButton() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if categories.count < UnlockGate.maxCategories {
                        Button {
                            requestAddCategory()
                        } label: {
                            Image("ph-plus")
                        }
                        .accessibilityLabel("Add category")
                    }
                }
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
        }
    }

    // MARK: Summary

    private var summary: some View {
        let readingCount = books.filter { $0.status == .reading }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                summaryStat("\(categories.count)", "categories")
                summaryStat("\(books.count)", books.count == 1 ? "book" : "books")
                summaryStat("\(readingCount)", "reading")
            }
            // Compartments used: one segment per compartment of the bookcase.
            HStack(spacing: 4) {
                ForEach(0..<UnlockGate.maxCategories, id: \.self) { index in
                    Capsule()
                        .fill(index < categories.count ? Color(hex: categories[index].colorHex) : Color.secondary.opacity(0.18))
                        .frame(height: 6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("\(categories.count) of \(UnlockGate.maxCategories) compartments used")
        }
        .padding(.vertical, 4)
    }

    private func summaryStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var footerText: String {
        var text = "Each category is one compartment of your bookcase, filled from the top left. Drag in Edit mode to rearrange the shelf."
        if !gate.isUnlocked {
            text += " Free: \(min(categories.count, UnlockGate.freeCategoryLimit)) of \(UnlockGate.freeCategoryLimit) categories. Get Pro for all \(UnlockGate.maxCategories)."
        }
        return text
    }

    // MARK: Actions

    private func requestAddCategory() {
        if gate.canAddCategory(currentCount: categories.count) {
            addingCategory = true
        } else if categories.count < UnlockGate.maxCategories {
            showingPaywall = true
        }
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
}

/// One category in the list: colour, name, position, book counts, pages progress, what's being read.
private struct CategoryCard: View {
    let category: BookCategory
    let index: Int

    var body: some View {
        let stats = CategoryStats(category)
        let color = Color(hex: category.colorHex)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: 10, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(CategoryStats.position(ofIndex: index))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if stats.streak > 0 {
                    Label("\(stats.streak)", image: "ph-flame-fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                        .accessibilityLabel("\(stats.streak)-day streak")
                }
            }

            if stats.bookCount == 0 {
                Text("No books yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    countChip("\(stats.bookCount)", stats.bookCount == 1 ? "book" : "books", icon: "ph-books")
                    if stats.reading > 0 { countChip("\(stats.reading)", "reading", icon: "ph-book-open") }
                    if stats.finished > 0 { countChip("\(stats.finished)", "done", icon: "ph-check-circle") }
                    if stats.wantToRead > 0 { countChip("\(stats.wantToRead)", "to read", icon: "ph-bookmark-simple") }
                }

                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: stats.progress)
                        .tint(color)
                    Text("\(stats.pagesRead.formatted()) of \(stats.totalPages.formatted()) pages · \(Int((stats.progress * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let book = stats.nowReading.first {
                    Label {
                        Text("Now reading **\(book.title)** · p. \(book.currentPage)")
                            .lineLimit(1)
                    } icon: {
                        Image("ph-bookmark-simple-fill").foregroundStyle(color)
                    }
                    .font(.caption)
                } else if let last = stats.lastRead {
                    Label("Last read \(last.formatted(.relative(presentation: .named)))", image: "ph-clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func countChip(_ value: String, _ label: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(icon)
            Text("\(value) \(label)")
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.secondary.opacity(0.12)))
        .lineLimit(1)
    }
}
