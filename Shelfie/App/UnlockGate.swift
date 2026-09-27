import Foundation
import Observation
import StoreKit

/// How someone has Shelfie Pro. Both plans unlock exactly the same features.
enum ProPlan: String {
    /// One-time, non-consumable purchase. Yours forever.
    case lifetime
    /// Auto-renewing monthly subscription.
    case monthly
}

/// The single place that knows whether Shelfie Pro is active (lifetime or monthly), and the free limits.
@MainActor
@Observable
final class UnlockGate {
    /// Kept from v1.0 so the existing lifetime product (and anyone who bought it) carries on working.
    static let lifetimeID = "com.cmtania.shelfie.unlock"
    static let monthlyID = "com.cmtania.shelfie.pro.monthly"
    static let productIDs = [lifetimeID, monthlyID]

    static let freeBookLimit = 10
    static let freeCategoryLimit = 3
    /// The bookcase has 10 compartments, so this is a hard cap even with Pro.
    static let maxCategories = 10

    /// The plan that gives Pro right now. Lifetime wins if someone has both.
    private(set) var activePlan: ProPlan?
    /// A monthly subscription is still active, even if Lifetime was bought later
    /// (so Settings can remind the person to cancel it).
    private(set) var hasMonthlySubscription = false
    private(set) var lifetime: Product?
    private(set) var monthly: Product?
    private(set) var isPurchasing = false
    var lastError: String?

    var isUnlocked: Bool { activePlan != nil }

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        if let cached = defaults.string(forKey: Prefs.planCacheKey), let plan = ProPlan(rawValue: cached) {
            activePlan = plan
        } else if defaults.bool(forKey: Prefs.unlockedCacheKey) {
            // Cache from before subscriptions existed: that was the lifetime Unlock.
            activePlan = .lifetime
        }
        updatesTask = Task { [weak self] in
            // Renewals, expiries, refunds and purchases made on other devices arrive here.
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
        Task {
            await refresh()
            await loadProducts()
        }
    }

    func canAddBook(currentCount: Int) -> Bool {
        isUnlocked || currentCount < Self.freeBookLimit
    }

    func canAddCategory(currentCount: Int) -> Bool {
        guard currentCount < Self.maxCategories else { return false }
        return isUnlocked || currentCount < Self.freeCategoryLimit
    }

    /// Months of Monthly that cost as much as Lifetime, rounded up: 249 / 59 = 4.2, so 5.
    /// Worked out from the live App Store prices, so it's right in every country.
    var lifetimePaybackMonths: Int? {
        guard let lifetime, let monthly, monthly.price > 0 else { return nil }
        let ratio = NSDecimalNumber(decimal: lifetime.price / monthly.price).doubleValue
        return Int(ratio.rounded(.up))
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: Self.productIDs)
            lifetime = products.first { $0.id == Self.lifetimeID }
            monthly = products.first { $0.id == Self.monthlyID }
        } catch {
            // Offline or not set up yet; the paywall shows "Loading price…" and retries.
        }
    }

    func refresh() async {
        var ownsLifetime = false
        var subscribed = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            if let expiry = transaction.expirationDate, expiry < .now { continue }
            switch transaction.productID {
            case Self.lifetimeID: ownsLifetime = true
            case Self.monthlyID: subscribed = true
            default: break
            }
        }
        hasMonthlySubscription = subscribed
        setPlan(ownsLifetime ? .lifetime : (subscribed ? .monthly : nil))
    }

    /// Returns true when the purchase went through.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refresh()
                    return true
                }
                lastError = "The purchase couldn't be verified. Please try Restore."
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
        return false
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refresh()
    }

    private func setPlan(_ plan: ProPlan?) {
        activePlan = plan
        let defaults = UserDefaults.standard
        defaults.set(plan?.rawValue, forKey: Prefs.planCacheKey)
        defaults.set(plan != nil, forKey: Prefs.unlockedCacheKey)
    }
}
