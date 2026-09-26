import SwiftData
import SwiftUI

struct NoteEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let book: Book
    let note: BookNote?

    @State private var text = ""
    @State private var page: Int?
    @State private var loaded = false
    @FocusState private var textFocused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .focused($textFocused)
                        .accessibilityLabel("Note")
                }
                Section {
                    NumberField("Page (optional)", value: $page)
                }
                if let note {
                    Section {
                        Button("Delete note", role: .destructive) {
                            context.delete(note)
                            try? context.save()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(note == nil ? "New note" : "Edit note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(trimmed.isEmpty)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                text = note?.text ?? ""
                page = note?.page ?? (book.currentPage > 0 ? book.currentPage : nil)
                textFocused = true
            }
        }
    }

    private func save() {
        let cleanPage = page.flatMap { $0 > 0 ? $0 : nil }
        if let note {
            note.text = trimmed
            note.page = cleanPage
            note.updatedAt = .now
        } else {
            let newNote = BookNote(text: trimmed, page: cleanPage)
            context.insert(newNote)
            newNote.book = book
        }
        try? context.save()
        dismiss()
    }
}
