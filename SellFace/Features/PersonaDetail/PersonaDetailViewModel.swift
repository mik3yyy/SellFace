import Foundation
import StoreKit

@MainActor
final class PersonaDetailViewModel {
    private(set) var persona: Persona
    weak var coordinator: AppCoordinator?

    private(set) var styleBundles: [StyleBundle] = []
    var onBundlesUpdated: (() -> Void)?
    var onPurchaseComplete: ((StyleBundle) -> Void)?
    var onError: ((String) -> Void)?

    init(persona: Persona, coordinator: AppCoordinator) {
        self.persona = persona
        self.coordinator = coordinator
    }

    // MARK: - Bundle loading (StoreKit only)

    func loadBundles() {
        let products = StoreKitManager.shared.products
        if products.isEmpty {
            // Products still loading — wait for them, then build
            styleBundles = []
            onBundlesUpdated?()
            Task {
                await StoreKitManager.shared.loadProducts()
                buildBundlesFromStoreKit()
            }
        } else {
            buildBundlesFromStoreKit()
        }
    }

    private func buildBundlesFromStoreKit() {
        let products = StoreKitManager.shared.products   // sorted cheapest → most expensive
        let unlocked = StoreKitManager.shared.purchasedProductIDs

        styleBundles = products.compactMap { product -> StyleBundle? in
            // Static metadata: maps productId → backend id, icon, regular price
            guard let meta = StyleBundle.staticMetadata.first(where: { $0.productId == product.id }) else {
                return nil  // unknown product — skip
            }

            // Show strikethrough only when Apple is charging less than the regular price
            let oldPrice: String?
            if let regularStr = meta.regularPrice,
               let regularVal = Decimal(string: regularStr.filter { $0.isNumber || $0 == "." }),
               product.price < regularVal {
                oldPrice = regularStr
            } else {
                oldPrice = nil
            }

            return StyleBundle(
                id: meta.id,
                name: product.displayName,
                description: meta.description,
                productId: product.id,
                price: product.displayPrice,
                oldPrice: oldPrice,
                previewImageName: meta.previewImageName,
                isUnlocked: unlocked.contains(product.id)
            )
        }
        onBundlesUpdated?()
    }

    // MARK: - Bundle interaction

    func didTapBundle(_ bundle: StyleBundle) {
        if bundle.isUnlocked {
            Task { await startGeneration(bundle: bundle) }
        } else {
            Task { await purchaseBundle(bundle) }
        }
    }

    private func startGeneration(bundle: StyleBundle) async {
        do {
            let body = CreateGenerationJobBody(personaId: persona.id, styleBundleId: bundle.productId)
            let job = try await APIClient.shared.request(
                endpoint: .createGenerationJob,
                body: body,
                responseType: GenerationJobResponse.self
            )
            coordinator?.showResults(persona: persona, bundle: bundle, jobId: job.id)
        } catch APIError.serverError(409, _) {
            coordinator?.showResults(persona: persona, bundle: bundle, jobId: nil)
        } catch {
            onError?("Could not start generation: \(error.localizedDescription)")
        }
    }

    private func purchaseBundle(_ bundle: StyleBundle) async {
        do {
            let success = try await StoreKitManager.shared.purchase(productId: bundle.productId)
            if success {
                LocalStorageManager.shared.unlockBundle(productId: bundle.productId)
                buildBundlesFromStoreKit()
                onPurchaseComplete?(bundle)
                await startGeneration(bundle: bundle)
            }
        } catch {
            onError?("Purchase failed: \(error.localizedDescription)")
        }
    }

    var isProcessing: Bool { persona.status == .processing || persona.status == .uploading }
}
