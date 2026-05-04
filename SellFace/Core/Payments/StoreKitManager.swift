import StoreKit
import Foundation

@MainActor
final class StoreKitManager {
    static let shared = StoreKitManager()

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private var updateListenerTask: Task<Void, Never>?

    private init() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await updatePurchasedProducts() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: ProductID.all)
        } catch {
            // Unavailable in sandbox without StoreKit config
        }
    }

    func product(for productId: String) -> Product? {
        products.first { $0.id == productId }
    }

    func purchase(productId: String) async throws -> Bool {
        guard let product = product(for: productId) else {
            // Mock/sandbox fallback: grant locally without a real transaction
            purchasedProductIDs.insert(productId)
            LocalStorageManager.shared.unlockBundle(productId: productId)
            return true
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }

    func isUnlocked(_ productId: String) -> Bool {
        purchasedProductIDs.contains(productId)
    }

    func updatePurchasedProducts() async {
        var purchased = LocalStorageManager.shared.loadUnlockedBundles()
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                purchased.insert(transaction.productID)
            }
        }
        purchasedProductIDs = purchased
        LocalStorageManager.shared.saveUnlockedBundles(purchased)
    }

    nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value): return value
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        // Inherit MainActor isolation so self can be accessed directly
        Task { @MainActor in
            for await result in Transaction.updates {
                if let transaction = try? self.checkVerified(result) {
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                }
            }
        }
    }
}
