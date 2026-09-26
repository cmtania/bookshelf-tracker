import RealityKit
import SwiftData
import SwiftUI

/// Home: the 3D room with the bookcase. Tap a compartment to look closer, tap a spine to open the book.
/// The glass chip row at the bottom mirrors the 3D view with full-size tap targets (and VoiceOver).
struct BookshelfScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(UnlockGate.self) private var gate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \BookCategory.sortIndex) private var categories: [BookCategory]
    @Query(sort: [SortDescriptor(\Book.shelfOrder), SortDescriptor(\Book.createdAt)]) private var books: [Book]

    @State private var scene = RoomScene()
    @State private var focused: Int?
    @State private var selectedBook: Book?
    @State private var addingBook = false
    @State private var addingCategory = false
    @State private var showingPaywall = false

    private var snapshot: ShelfSnapshot {
        ShelfSnapshot.make(categories: categories, books: books)
    }

    private var focusedCategory: BookCategory? {
        guard let focused, focused < categories.count else { return nil }
        return categories[focused]
    }

    var body: some View {
        let shelf = self.snapshot
        ZStack {
            GeometryReader { geo in
                RealityView { content in
                    scene.setViewSize(geo.size)
                    content.add(scene.root)
                }
                .gesture(
                    SpatialTapGesture()
                        .targetedToAnyEntity()
                        .onEnded { value in handleTap(value.entity) }
                )
                .onChange(of: geo.size) { _, size in
                    scene.setViewSize(size)
                }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)

            VStack(spacing: 0) {
                topBar(shelf)
                Spacer(minLength: 0)
                chipRow(shelf)
            }
            .padding(.bottom, 8)
        }
        .onChange(of: shelf, initial: true) { _, newValue in
            scene.update(newValue)
            if let focused, newValue.compartments[focused].isEmpty {
                setFocus(nil)
            }
        }
        .onChange(of: reduceMotion, initial: true) { _, value in
            scene.reduceMotion = value
        }
        .sheet(item: $selectedBook, onDismiss: { scene.pushBack() }) { book in
            BookDetailView(book: book)
        }
        .sheet(isPresented: $addingBook) {
            BookEditView(book: nil, initialCategory: focusedCategory)
        }
        .sheet(isPresented: $addingCategory) {
            CategoryEditSheet(category: nil)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }

    // MARK: Overlay

    private func topBar(_ snapshot: ShelfSnapshot) -> some View {
        HStack(spacing: 12) {
            if focused != nil {
                Button {
                    setFocus(nil)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Back to bookshelf")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(focusedCategory?.name ?? "My Bookshelf")
                    .font(.title2.bold())
                    .lineLimit(1)
                Text(subtitle(snapshot))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                requestAddBook()
            } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Add book")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func subtitle(_ snapshot: ShelfSnapshot) -> String {
        if let focused {
            let count = snapshot.compartments[focused].books.count
            return count == 0 ? "No books yet" : "\(count) \(count == 1 ? "book" : "books") · tap a spine to open"
        }
        let streak = StreakCalculator().currentStreak(books.flatMap(\.sessionDates))
        let count = "\(books.count) \(books.count == 1 ? "book" : "books")"
        return streak > 0 ? "\(count) · 🔥 \(streak)-day streak" : "\(count) · tap a shelf to look closer"
    }

    private func chipRow(_ snapshot: ShelfSnapshot) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let focused {
                    let shelfBooks = snapshot.compartments[focused].books
                    ForEach(shelfBooks) { book in
                        chip(book.title, colorHex: book.spineColorHex) { open(bookID: book.id) }
                    }
                    if shelfBooks.isEmpty {
                        chip("Add a book", systemImage: "plus") { requestAddBook() }
                    }
                } else {
                    ForEach(Array(categories.prefix(BookcaseGeometry.compartmentCount).enumerated()), id: \.element.id) { index, category in
                        chip(category.name, colorHex: category.colorHex) { setFocus(index) }
                    }
                    if categories.count < BookcaseGeometry.compartmentCount {
                        chip("Category", systemImage: "plus") { requestAddCategory() }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollClipDisabled()
    }

    private func chip(_ title: String, colorHex: String? = nil, systemImage: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let colorHex {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 10, height: 10)
                }
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .lineLimit(1)
            }
            .font(.subheadline.weight(.medium))
            .frame(minHeight: 32)
        }
        .buttonStyle(.glass)
    }

    // MARK: Actions

    private func handleTap(_ entity: Entity) {
        let hit = RoomScene.resolve(entity)
        guard let index = hit.compartment else { return }
        if index >= categories.count {
            requestAddCategory()
        } else if focused == index, let bookID = hit.bookID {
            open(bookID: bookID)
        } else if focused != index {
            setFocus(index)
        }
    }

    private func setFocus(_ index: Int?) {
        withAnimation(.snappy) { focused = index }
        scene.focus(compartment: index)
    }

    private func open(bookID: UUID) {
        guard let book = books.first(where: { $0.id == bookID }) else { return }
        scene.pullOut(bookID: bookID)
        let delay: Duration = reduceMotion ? .zero : .milliseconds(300)
        Task {
            try? await Task.sleep(for: delay)
            selectedBook = book
        }
    }

    private func requestAddBook() {
        if categories.isEmpty {
            requestAddCategory()
        } else if gate.canAddBook(currentCount: books.count) {
            addingBook = true
        } else {
            showingPaywall = true
        }
    }

    private func requestAddCategory() {
        guard categories.count < UnlockGate.maxCategories else { return }
        if gate.canAddCategory(currentCount: categories.count) {
            addingCategory = true
        } else {
            showingPaywall = true
        }
    }
}
