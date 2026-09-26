import Foundation
import Observation
import StoreKit

/// The single place that knows whether the one-time Unlock was bought, and the free limits.
@MainActor
@Observable
final class UnlockGate {
    static let productID = "com.cmtania.shelfie.unlock"
    static let freeBookLimit = 10
    static let freeCategoryLimit = 3
    /// The bookcase has 10 compartments, so this is a hard cap even when unlocked.
    static let maxCategories = 10

    private(set) var isUnlocked: Bool
    private(set) var product: Product?
    private(set) var isPurchasing = false
    var lastError: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        isUnlocked = UserDefaults.standard.bool(forKey: Prefs.unlockedCacheKey)
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
        Task {
            await refresh()
            await loadProduct()
        }
    }

    func canAddBook(currentCount: Int) -> Bool {
        isUnlocked || currentCount < Self.freeBookLimit
    }

    func canAddCategory(currentCount: Int) -> Bool {
        guard currentCount < Self.maxCategories else { return false }
        return isUnlocked || currentCount < Self.freeCategoryLimit
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            product = nil
        }
    }

    func refresh() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        setUnlocked(unlocked)
    }

    func purchase() async {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    setUnlocked(true)
                } else {
                    lastError = "The purchase couldn't be verified. Please try Restore."
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refresh()
    }

    private func setUnlocked(_ value: Bool) {
        isUnlocked = value
        UserDefaults.standard.set(value, forKey: Prefs.unlockedCacheKey)
    }
}
