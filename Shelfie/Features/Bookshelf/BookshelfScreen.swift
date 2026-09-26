import RealityKit
import SwiftData
import SwiftUI

/// Home: the 3D room with the bookcase. Tap a compartment to look closer; tap a spine and the book
/// slides out, flies up and turns to show its front cover, with Log reading and Edit underneath.
/// The glass chip row at the bottom mirrors the 3D view with full-size tap targets (and VoiceOver).
struct BookshelfScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(UnlockGate.self) private var gate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \BookCategory.sortIndex) private var categories: [BookCategory]
    @Query(sort: [SortDescriptor(\Book.shelfOrder), SortDescriptor(\Book.createdAt)]) private var books: [Book]

    @State private var scene = RoomScene()
    @State private var focused: Int?
    /// The book lifted out of the shelf. Looked up from the query each time, so a deleted book just disappears.
    @State private var presentedID: UUID?
    @State private var showsPresentedControls = false
    @State private var readingBook: Book?
    @State private var editingBook: Book?
    @State private var pendingDelete = false
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

    private var presentedBook: Book? {
        guard let presentedID else { return nil }
        return books.first { $0.id == presentedID }
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

            if let book = presentedBook {
                presentationOverlay(book)
            } else {
                VStack(spacing: 0) {
                    topBar(shelf)
                    Spacer(minLength: 0)
                    chipRow(shelf)
                }
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
        .onChange(of: shelf, initial: true) { _, newValue in
            scene.update(newValue)
            if let focused, newValue.compartments[focused].isEmpty {
                setFocus(nil)
            }
            if let presentedID, !newValue.compartments.contains(where: { $0.books.contains { $0.id == presentedID } }) {
                closePresentation(animated: false)
            }
        }
        .onChange(of: reduceMotion, initial: true) { _, value in
            scene.reduceMotion = value
        }
        .sheet(item: $readingBook) { book in
            BookDetailView(book: book)
        }
        .sheet(item: $editingBook, onDismiss: deleteIfRequested) { book in
            BookEditView(book: book, initialCategory: nil, onDelete: { pendingDelete = true })
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

    /// Shown while a book is up close. Tap outside the buttons to put it back; drag to turn it.
    private func presentationOverlay(_ book: Book) -> some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { closePresentation(animated: true) }
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in scene.rotatePresented(dragWidth: value.translation.width) }
                        .onEnded { _ in scene.endRotatePresented() }
                )
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Button {
                        closePresentation(animated: true)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Put the book back")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer(minLength: 0)

                if showsPresentedControls {
                    presentedControls(book)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 8)
        }
    }

    private func presentedControls(_ book: Book) -> some View {
        let streak = StreakCalculator().currentStreak(book.sessionDates)
        return VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(book.title)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 12) {
                    Label("Page \(book.currentPage) of \(book.totalPages)", systemImage: "book.closed")
                    Label("\(streak)-day streak", systemImage: "flame.fill")
                        .foregroundStyle(streak > 0 ? Color.orange : Color.secondary)
                }
                .font(.footnote.weight(.medium))
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .accessibilityElement(children: .combine)

            HStack(spacing: 12) {
                Button {
                    readingBook = book
                } label: {
                    Label("Log reading", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.glassProminent)

                Button {
                    editingBook = book
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(.horizontal, 16)
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
        guard books.contains(where: { $0.id == bookID }) else { return }
        showsPresentedControls = false
        withAnimation(.snappy) { presentedID = bookID }
        Task {
            await scene.present(bookID: bookID)
            // Only if the user hasn't already closed it or opened another book meanwhile.
            guard presentedID == bookID else { return }
            withAnimation(.snappy) { showsPresentedControls = true }
        }
    }

    private func closePresentation(animated: Bool) {
        withAnimation(.snappy) {
            showsPresentedControls = false
            presentedID = nil
        }
        if animated {
            Task { await scene.dismissPresented() }
        } else {
            scene.dismissPresentedImmediately()
        }
    }

    /// Runs after the Edit sheet closes. Put the book back first, then delete it, so nothing
    /// on screen still reads the book once it's gone.
    private func deleteIfRequested() {
        guard pendingDelete, let book = presentedBook else { return }
        pendingDelete = false
        closePresentation(animated: false)
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            context.delete(book)
            try? context.save()
            await ReminderScheduler.reschedule(context: context)
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
