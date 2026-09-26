import StoreKit
import SwiftUI

/// Shown only when the user reaches a free limit, or from Settings. Always closable.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UnlockGate.self) private var gate

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 12)
                        .accessibilityHidden(true)
                    Text("Unlock your whole library")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                    Text("The free version holds \(UnlockGate.freeBookLimit) books in \(UnlockGate.freeCategoryLimit) categories. Unlock once to fill every shelf.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 14) {
                        feature("infinity", "Unlimited books")
                        feature("square.grid.2x2.fill", "All \(UnlockGate.maxCategories) bookcase compartments")
                        feature("checkmark.seal.fill", "One-time purchase, no subscription")
                        feature("heart.fill", "Supports an indie developer")
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        Task { await gate.purchase() }
                    } label: {
                        Group {
                            if gate.isPurchasing {
                                ProgressView()
                            } else {
                                Text(buyTitle)
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(gate.product == nil || gate.isPurchasing)

                    Text("One-time payment. No subscription.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 24) {
                        Button("Restore") {
                            Task { await gate.restore() }
                        }
                        Link("Terms", destination: AppLinks.terms)
                        Link("Privacy", destination: AppLinks.privacy)
                    }
                    .font(.footnote)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
            .alert(
                "Purchase problem",
                isPresented: Binding(get: { gate.lastError != nil }, set: { if !$0 { gate.lastError = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(gate.lastError ?? "")
            }
            .onChange(of: gate.isUnlocked) { _, unlocked in
                if unlocked { dismiss() }
            }
            .task {
                if gate.product == nil {
                    await gate.loadProduct()
                }
            }
        }
    }

    private var buyTitle: String {
        if let product = gate.product {
            return "Unlock for \(product.displayPrice)"
        }
        return "Loading price…"
    }

    private func feature(_ systemImage: String, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
        }
    }
}
