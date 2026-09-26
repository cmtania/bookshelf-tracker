import SwiftData
import SwiftUI

/// Add (category == nil) or rename/recolour a category. New categories take the next free compartment.
struct CategoryEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \BookCategory.sortIndex) private var categories: [BookCategory]

    let category: BookCategory?

    @State private var name = ""
    @State private var colorHex = Palette.colors[4]
    @State private var loaded = false
    @FocusState private var nameFocused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. Fantasy", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($nameFocused)
                }
                Section("Color") {
                    ColorSwatchPicker(selection: $colorHex)
                }
            }
            .navigationTitle(category == nil ? "New category" : "Edit category")
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
                if let category {
                    name = category.name
                    colorHex = category.colorHex
                } else {
                    let used = Set(categories.map(\.colorHex))
                    colorHex = Palette.colors.first { !used.contains($0) } ?? Palette.colors[4]
                    nameFocused = true
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        if let category {
            category.name = trimmed
            category.colorHex = colorHex
        } else {
            let next = (categories.map(\.sortIndex).max() ?? -1) + 1
            context.insert(BookCategory(name: trimmed, colorHex: colorHex, sortIndex: next))
        }
        try? context.save()
        dismiss()
    }
}
