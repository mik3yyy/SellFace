import StoreKit
import Foundation

enum StoreKitPurchaseError: LocalizedError {
    case productNotFound
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Couldn't load this purchase from the App Store. Make sure you're signed into your Apple ID in Settings and try again."
        case .verificationFailed:
            return "Purchase verification failed. Please contact support."
        }
    }
}

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
            let loaded = try await Product.products(for: ProductID.all)
            products = loaded.sorted { $0.price < $1.price }
            print("[StoreKit] Loaded \(products.count) products: \(products.map(\.id))")
        } catch {
            print("[StoreKit] loadProducts failed: \(error)")
        }
    }

    func product(for productId: String) -> Product? {
        products.first { $0.id == productId }
    }

    /// Returns the App Store–formatted local price string (e.g. "£2.99").
    /// Falls back to nil if products haven't loaded yet.
    func localizedPrice(for productId: String) -> String? {
        product(for: productId)?.displayPrice
    }

    func purchase(productId: String) async throws -> Bool {
        if APIClient.shared.mockMode {
            purchasedProductIDs.insert(productId)
            LocalStorageManager.shared.unlockBundle(productId: productId)
            return true
        }

        // Load products if missing, retry once on transient failure
        if products.isEmpty { await loadProducts() }
        if products.isEmpty { await loadProducts() }

        guard let product = product(for: productId) else {
            throw StoreKitPurchaseError.productNotFound
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
        // StoreKit currentEntitlements is the source of truth.
        // Start empty so stale local data (e.g. from mock mode) never bleeds in.
        var purchased = Set<String>()
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
