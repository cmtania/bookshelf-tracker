import SwiftUI

/// "Reset all data" needs more than one tap: the user types CONFIRM, and only then
/// does "Yes, continue" become available.
struct ResetDataSheet: View {
    @Environment(\.dismiss) private var dismiss
    /// Runs the reset. Called after the sheet has closed.
    let onConfirm: () -> Void

    static let confirmationWord = "CONFIRM"

    @State private var typed = ""
    @FocusState private var fieldFocused: Bool

    private var isConfirmed: Bool {
        typed.trimmingCharacters(in: .whitespacesAndNewlines) == Self.confirmationWord
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Image("ph-warning-fill")
                            .font(.title)
                            .foregroundStyle(.red)
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(Color.red.opacity(0.12)))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset all data?")
                                .font(.title2.bold())
                            Text("This can’t be undone.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("This deletes, from this device:")
                            .font(.subheadline.weight(.semibold))
                        deletedRow("ph-books", "Every book on your shelf")
                        deletedRow("ph-squares-four", "All your categories")
                        deletedRow("ph-notepad", "All notes")
                        deletedRow("ph-calendar-dots", "Every reading session and streak")
                        Text("You’ll start again with an empty bookcase. Your Shelfie Pro purchase and your settings are kept.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type \(Self.confirmationWord) to continue")
                            .font(.subheadline.weight(.semibold))
                        TextField(Self.confirmationWord, text: $typed)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($fieldFocused)
                            .font(.body.monospaced())
                            .padding(.horizontal, 14)
                            .frame(minHeight: 48)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(isConfirmed ? Color.red : Color.clear, lineWidth: 2)
                            )
                            .accessibilityLabel("Type \(Self.confirmationWord) to continue")
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button(role: .destructive) {
                        dismiss()
                        onConfirm()
                    } label: {
                        Text("Yes, continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                    .disabled(!isConfirmed)

                    Button("Cancel") { dismiss() }
                        .font(.body.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image("ph-x")
                    }
                    .accessibilityLabel("Close")
                }
            }
            .onAppear { fieldFocused = true }
        }
        .presentationDetents([.large])
    }

    private func deletedRow(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(symbol)
                .foregroundStyle(.red)
        }
        .font(.subheadline)
    }
}
