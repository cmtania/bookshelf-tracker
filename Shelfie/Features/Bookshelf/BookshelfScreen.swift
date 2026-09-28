import RealityKit
import SwiftData
import SwiftUI

/// Home: the 3D room with the bookcase. Tap a compartment to look closer; tap a spine and the book
/// slides out (with a soft sound), flies up and turns to show its front cover, with Log reading
/// and Edit underneath. Pinch to zoom in or out, and drag to look around while zoomed in.
/// The glass chip row at the bottom mirrors the 3D view with full-size tap targets (and VoiceOver).
struct BookshelfScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(UnlockGate.self) private var gate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass

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
    /// The book waiting for "Delete book?" to be confirmed (from the 3D book or a chip).
    @State private var bookToDelete: Book?
    @State private var addingBook = false
    @State private var addingCategory = false
    @State private var showingPaywall = false
    @State private var editingTheme = false
    @State private var sharing = false
    @State private var renamingCategory: BookCategory?
    @State private var isPinching = false

    @AppStorage(Prefs.shelfColorKey) private var shelfID = RoomTheme.default.shelfID
    @AppStorage(Prefs.wallColorKey) private var wallID = RoomTheme.default.wallID
    @AppStorage(Prefs.floorColorKey) private var floorID = RoomTheme.default.floorID
    @AppStorage(Prefs.bookcaseStyleKey) private var styleID = RoomTheme.default.styleID

    private var snapshot: ShelfSnapshot {
        ShelfSnapshot.make(categories: categories, books: books)
    }

    /// Room colors are part of the Unlock; without it (e.g. after a refund) the default room shows.
    private var theme: RoomTheme {
        guard gate.isUnlocked else { return .default }
        return RoomTheme(shelfID: shelfID, wallID: wallID, floorID: floorID, styleID: styleID)
    }

    /// Text over the room follows the wall colour, not the system appearance: a white room
    /// needs dark text even in Dark Mode, and a charcoal wall needs light text.
    private var overlayScheme: ColorScheme {
        UIColor(hex: theme.wall.hex).luminance < 0.5 ? .dark : .light
    }

    private var focusedCategory: BookCategory? {
        guard let focused, focused < categories.count else { return nil }
        return categories[focused]
    }

    /// On iPad (and wide windows) room colors open in a side panel instead of a half-height sheet.
    private var usesSidePanel: Bool {
        sizeClass == .regular
    }

    private var roomPreview: RoomScene.RoomPreview? {
        guard editingTheme else { return nil }
        return usesSidePanel ? .wholeView : .topHalf
    }

    private var themeEditor: some View {
        NavigationStack {
            RoomThemeEditor()
                .navigationTitle("Room colors")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { editingTheme = false }
                    }
                }
        }
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
                // Two fingers zoom in and out; one finger moves around while zoomed in.
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { value in
                            guard !editingTheme else { return }
                            isPinching = true
                            scene.pinchChanged(scale: value.magnification, anchor: value.startAnchor)
                        }
                        .onEnded { _ in
                            isPinching = false
                            scene.pinchEnded()
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            guard !editingTheme else { return }
                            // A pinch also moves the fingers; let it own the camera until it ends.
                            if isPinching {
                                scene.panEnded()
                            } else {
                                scene.panChanged(translation: value.translation, viewSize: geo.size)
                            }
                        }
                        .onEnded { _ in scene.panEnded() }
                )
                .onChange(of: geo.size) { _, size in
                    scene.setViewSize(size)
                }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)

            Group {
                if let book = presentedBook {
                    presentationOverlay(book)
                } else if !editingTheme {
                    // Hidden while choosing room colors, so nothing covers the room.
                    VStack(spacing: 0) {
                        topBar(shelf)
                        Spacer(minLength: 0)
                        chipRow(shelf)
                    }
                    .padding(.bottom, 8)
                    .transition(.opacity)
                }
            }
            .environment(\.colorScheme, overlayScheme)
            .animation(.snappy, value: editingTheme)
        }
        .onChange(of: editingTheme) { _, _ in
            // Pull back to the whole room while room colors are open, and return afterwards.
            scene.setRoomPreview(roomPreview)
        }
        .onChange(of: usesSidePanel) { _, _ in
            scene.setRoomPreview(roomPreview)
        }
        .onChange(of: theme, initial: true) { _, newTheme in
            scene.setTheme(newTheme)
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
        .task {
            SoundEffects.preload(.bookPull)
        }
        // Touch feedback: a tick when zooming into a compartment, a soft knock when a book comes out.
        .sensoryFeedback(.selection, trigger: focused)
        .sensoryFeedback(trigger: presentedID) { _, new in
            new == nil ? nil : .impact(weight: .light)
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
        // iPhone: a sheet fixed at half the screen; the camera frames the whole room in the top
        // half, so every color change shows live above the sheet.
        // (A size-class change while editing moves the editor instead of closing it.)
        .sheet(isPresented: Binding(
            get: { editingTheme && !usesSidePanel },
            set: { if !$0 && !usesSidePanel { editingTheme = false } }
        )) {
            themeEditor
                .presentationDetents([.fraction(0.5)])
                .presentationDragIndicator(.hidden)
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.5)))
                .presentationContentInteraction(.scrolls)
        }
        // iPad: a panel beside the room, which stays in full view.
        .inspector(isPresented: Binding(
            get: { editingTheme && usesSidePanel },
            set: { if !$0 && usesSidePanel { editingTheme = false } }
        )) {
            themeEditor
                .inspectorColumnWidth(min: 320, ideal: 360, max: 420)
        }
        .sheet(isPresented: $sharing) {
            ShareShelfSheet(card: shareCard(shelf))
        }
        .sheet(item: $renamingCategory) { category in
            CategoryEditSheet(category: category)
        }
        .confirmationDialog(
            "Delete “\(bookToDelete?.title ?? "this book")”?",
            isPresented: Binding(get: { bookToDelete != nil }, set: { if !$0 { bookToDelete = nil } }),
            titleVisibility: .visible,
            presenting: bookToDelete
        ) { book in
            Button("Delete book", role: .destructive) { delete(book) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text(BookDeletion.confirmationMessage)
        }
    }

    private func shareCard(_ snapshot: ShelfSnapshot) -> ShelfShareCard {
        ShelfShareCard(
            snapshot: snapshot,
            theme: theme,
            bookCount: books.count,
            readingCount: books.filter { $0.status == .reading }.count,
            finishedCount: books.filter { $0.status == .finished }.count,
            streak: StreakCalculator().currentStreak(books.flatMap(\.sessionDates))
        )
    }

    // MARK: Overlay

    private func topBar(_ snapshot: ShelfSnapshot) -> some View {
        HStack(spacing: 12) {
            if focused != nil {
                Button {
                    setFocus(nil)
                } label: {
                    Image("ph-caret-left")
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
                subtitle(snapshot)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            // On glass, so the title stays readable over the ceiling's moulding and lights.
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
            Spacer(minLength: 8)
            // Zoomed out: room colors + share the whole shelf.
            // Zoomed into a compartment: rename it + add a book to it.
            if let category = focusedCategory {
                Button {
                    renamingCategory = category
                } label: {
                    Image("ph-pencil-simple")
                        .font(.headline)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Rename \(category.name)")

                Button {
                    requestAddBook()
                } label: {
                    Image("ph-plus")
                        .font(.headline)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Add book to \(category.name)")
            } else {
                Button {
                    if gate.isUnlocked {
                        editingTheme = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    Image("ph-paint-brush-fill")
                        .font(.headline)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Room colors")

                Button {
                    sharing = true
                } label: {
                    Image("ph-export")
                        .font(.headline)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Share your shelf")
            }
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
                    Button {
                        bookToDelete = book
                    } label: {
                        Image("ph-trash")
                            .font(.headline)
                            .foregroundStyle(.red)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Delete \(book.title)")
                    Spacer()
                    Button {
                        closePresentation(animated: true)
                    } label: {
                        Image("ph-x")
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
                    Label("Page \(book.currentPage) of \(book.totalPages)", image: "ph-book")
                    Label("\(streak)-day streak", image: "ph-flame-fill")
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
                    Label("Log reading", image: "ph-plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.glassProminent)

                Button {
                    editingBook = book
                } label: {
                    Label("Edit", image: "ph-pencil-simple")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.glass)
            }
        }
        // Phone width on iPad too, so the card and buttons don't stretch across the screen.
        .frame(maxWidth: 520)
        .padding(.horizontal, 16)
    }

    private func subtitle(_ snapshot: ShelfSnapshot) -> Text {
        if let focused {
            let count = snapshot.compartments[focused].books.count
            return Text(count == 0 ? "No books yet" : "\(count) \(count == 1 ? "book" : "books") · tap a spine to open")
        }
        let streak = StreakCalculator().currentStreak(books.flatMap(\.sessionDates))
        let count = "\(books.count) \(books.count == 1 ? "book" : "books")"
        guard streak > 0 else { return Text("\(count) · tap a shelf to look closer") }
        // The Phosphor flame in orange, inline with the text.
        let flame = Text(Image("ph-flame-fill")).foregroundStyle(.orange)
        return Text("\(count) · \(flame) \(streak)-day streak")
    }

    private func chipRow(_ snapshot: ShelfSnapshot) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let focused {
                    let shelfBooks = snapshot.compartments[focused].books
                    ForEach(shelfBooks) { book in
                        chip(book.title, colorHex: book.spineColorHex) { open(bookID: book.id) }
                            .contextMenu {
                                Button {
                                    open(bookID: book.id)
                                } label: {
                                    Label("Open", image: "ph-book-open")
                                }
                                Button(role: .destructive) {
                                    bookToDelete = books.first { $0.id == book.id }
                                } label: {
                                    Label("Delete book", image: "ph-trash")
                                }
                            }
                    }
                    if shelfBooks.isEmpty {
                        chip("Add a book", icon: "ph-plus") { requestAddBook() }
                    }
                } else {
                    ForEach(Array(categories.prefix(BookcaseGeometry.compartmentCount).enumerated()), id: \.element.id) { index, category in
                        chip(category.name, colorHex: category.colorHex) { setFocus(index) }
                    }
                    if categories.count < BookcaseGeometry.compartmentCount {
                        chip("Category", icon: "ph-plus") { requestAddCategory() }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollClipDisabled()
    }

    private func chip(_ title: String, colorHex: String? = nil, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let colorHex {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 10, height: 10)
                }
                if let icon {
                    Image(icon)
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
        // While picking room colors the room is just a preview; taps shouldn't zoom or open books.
        guard !editingTheme else { return }
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
        SoundEffects.play(.bookPull)
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
        delete(book)
    }

    /// Deletes a book. If it's the one pulled out of the shelf, put it back first, so nothing
    /// on screen still reads the book once it's gone.
    private func delete(_ book: Book) {
        if presentedID == book.id {
            closePresentation(animated: false)
        }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            await BookDeletion.delete(book, in: context)
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
