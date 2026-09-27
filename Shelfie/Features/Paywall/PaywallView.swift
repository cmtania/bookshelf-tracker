import StoreKit
import SwiftUI

/// Shown only when the user reaches a free limit, or from Settings. Always closable.
/// Two ways to get Shelfie Pro: Lifetime (pre-selected, the better deal) or Monthly.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UnlockGate.self) private var gate

    @State private var selected: ProPlan = .lifetime
    @State private var remindToCancel = false
    @State private var managingSubscription = false

    /// Monthly subscribers only see Lifetime here: the upgrade.
    private var isUpgrade: Bool { gate.activePlan == .monthly }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88)
                        .padding(.top, 8)
                        .accessibilityHidden(true)
                    Text(isUpgrade ? "Keep Pro forever" : "Get Shelfie Pro")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                    Text(isUpgrade
                        ? "You’re on Pro Monthly. Pay once for Lifetime and never pay again."
                        : "The free version holds \(UnlockGate.freeBookLimit) books in \(UnlockGate.freeCategoryLimit) categories. Go Pro to fill every shelf and color your room.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        feature("infinity", "Unlimited books")
                        feature("square.grid.2x2.fill", "All \(UnlockGate.maxCategories) bookcase compartments")
                        feature("paintbrush.fill", "Room colors, premium finishes and floors")
                        feature("heart.fill", "Supports an indie developer")
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)))

                    VStack(spacing: 12) {
                        planOption(.lifetime)
                        if !isUpgrade {
                            planOption(.monthly)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        buy()
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
                    .disabled(product(for: selected) == nil || gate.isPurchasing)

                    Text(termsLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 24) {
                        Button("Restore") {
                            Task { await gate.restore() }
                        }
                        Link("Terms of Use", destination: AppLinks.terms)
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
            // After upgrading to Lifetime, the old subscription keeps renewing until it's cancelled.
            .alert("You own Shelfie Pro forever", isPresented: $remindToCancel) {
                Button("Manage subscription") { managingSubscription = true }
                Button("Later", role: .cancel) { dismiss() }
            } message: {
                Text("Cancel your monthly subscription so you aren’t charged again. Pro stays on either way.")
            }
            .manageSubscriptionsSheet(isPresented: $managingSubscription)
            .onChange(of: managingSubscription) { _, showing in
                if !showing { dismiss() }
            }
            .task {
                if gate.lifetime == nil || gate.monthly == nil {
                    await gate.loadProducts()
                }
            }
        }
    }

    // MARK: Plans

    private func planOption(_ plan: ProPlan) -> some View {
        let isSelected = selected == plan
        let product = product(for: plan)
        return Button {
            withAnimation(.snappy) { selected = plan }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(plan == .lifetime ? "Lifetime" : "Monthly")
                            .font(.headline)
                        if plan == .lifetime {
                            Text("BEST VALUE")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .foregroundStyle(.white)
                                .background(Capsule().fill(Color.accentColor))
                        }
                    }
                    Text(planSubtitle(plan))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(product?.displayPrice ?? "…")
                        .font(.headline)
                    Text(plan == .lifetime ? "once" : "per month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func planSubtitle(_ plan: ProPlan) -> String {
        switch plan {
        case .lifetime:
            if let months = gate.lifetimePaybackMonths {
                return "Pay once, yours forever. Pays for itself in \(months) months."
            }
            return "Pay once, yours forever."
        case .monthly:
            return "Cancel anytime."
        }
    }

    private func product(for plan: ProPlan) -> Product? {
        plan == .lifetime ? gate.lifetime : gate.monthly
    }

    private var buyTitle: String {
        guard let product = product(for: selected) else { return "Loading price…" }
        switch selected {
        case .lifetime: return "Get Lifetime for \(product.displayPrice)"
        case .monthly: return "Subscribe for \(product.displayPrice)/month"
        }
    }

    /// The wording App Review expects next to the buy button.
    private var termsLine: String {
        switch selected {
        case .lifetime:
            return "One-time payment. No subscription."
        case .monthly:
            let price = gate.monthly?.displayPrice ?? "The monthly price"
            return "\(price) per month, charged to your Apple ID. Renews automatically each month unless cancelled at least 24 hours before the renewal date. Manage or cancel anytime in Settings › Apple Account › Subscriptions."
        }
    }

    private func buy() {
        guard let product = product(for: selected) else { return }
        let wasSubscribed = gate.hasMonthlySubscription
        Task {
            guard await gate.purchase(product) else { return }
            if selected == .lifetime && wasSubscribed {
                remindToCancel = true
            } else {
                dismiss()
            }
        }
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
