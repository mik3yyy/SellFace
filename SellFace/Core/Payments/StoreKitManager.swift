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

    /// Set true to bypass real StoreKit — purchases succeed instantly.
    /// Flip back to false before App Store submission.
    static var bypassPayments = true

    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private var updateListenerTask: Task<Void, Never>?
    private var productsLoadTask: Task<Void, Never>?

    private init() {
        updateListenerTask = listenForTransactions()
        productsLoadTask = Task { await loadProducts() }
        Task { await updatePurchasedProducts() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func loadProducts() async {
        guard products.isEmpty else { return }   // already loaded — skip the network round-trip
        let requestedIDs = ProductID.all.sorted()
        print("[StoreKit] Requesting \(requestedIDs.count) products: \(requestedIDs)")
        print("[StoreKit] Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        #if targetEnvironment(simulator)
        print("[StoreKit] ⚠️ Running on SIMULATOR — real sandbox products will never load on Simulator")
        #else
        print("[StoreKit] Running on real device")
        #endif
        do {
            let loaded = try await Product.products(for: ProductID.all)
            products = loaded.sorted { $0.price < $1.price }
            if loaded.isEmpty {
                print("[StoreKit] ⚠️ 0 products returned with no error. Likely causes:")
                print("[StoreKit]   1. Paid Apps Agreement not yet propagated — wait up to 1 hr after activation")
                print("[StoreKit]   2. Bundle ID mismatch — check App Store Connect IAP bundle ID matches above")
                print("[StoreKit]   3. IAP products not yet approved (must be 'Ready to Submit' or 'Approved')")
                print("[StoreKit]   4. No sandbox tester signed in on device (Settings → App Store → Sandbox Account)")
            } else {
                print("[StoreKit] ✅ Loaded \(loaded.count) products:")
                for p in products {
                    print("[StoreKit]   \(p.id)  →  \"\(p.displayName)\"  \(p.displayPrice)  (raw: \(p.price))")
                }
            }
        } catch {
            print("[StoreKit] ❌ loadProducts failed: \(error)")
            print("[StoreKit]   Error type: \(type(of: error))")
            print("[StoreKit]   Localized: \(error.localizedDescription)")
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
        if APIClient.shared.mockMode || StoreKitManager.bypassPayments {
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
        // In bypass mode, Apple has no real transactions — restore from LocalStorage instead
        // so bypass purchases survive app restarts.
        if StoreKitManager.bypassPayments {
            purchasedProductIDs = LocalStorageManager.shared.loadUnlockedBundles()
            return
        }
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
