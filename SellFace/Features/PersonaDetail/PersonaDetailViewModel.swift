import Foundation

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

    func loadBundles() {
        let unlocked = StoreKitManager.shared.purchasedProductIDs
        styleBundles = StyleBundle.mockBundles.map { bundle in
            var b = bundle; b.isUnlocked = unlocked.contains(bundle.productId); return b
        }
        onBundlesUpdated?()
        Task { await fetchStylesFromBackend() }
    }

    private func fetchStylesFromBackend() async {
        do {
            let responses = try await APIClient.shared.request(
                endpoint: .getStyles,
                responseType: [StyleBundleResponse].self
            )
            let unlocked = StoreKitManager.shared.purchasedProductIDs
            styleBundles = responses
                .filter { $0.isActive }
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { $0.toStyleBundle(unlocked: unlocked.contains($0.productId)) }
            applyStoreKitPrices()
            onBundlesUpdated?()
        } catch {
            applyStoreKitPrices()
        }
    }

    /// Replaces hardcoded backend price strings with real App Store localized prices.
    private func applyStoreKitPrices() {
        styleBundles = styleBundles.map { bundle in
            guard let skPrice = StoreKitManager.shared.localizedPrice(for: bundle.productId) else {
                return bundle
            }
            var b = bundle
            b.price = skPrice
            return b
        }
    }

    func didTapBundle(_ bundle: StyleBundle) {
        if bundle.isUnlocked {
            Task { await startGeneration(bundle: bundle) }
        } else {
            Task { await purchaseBundle(bundle) }
        }
    }

    private func startGeneration(bundle: StyleBundle) async {
        do {
            let body = CreateGenerationJobBody(personaId: persona.id, styleBundleId: bundle.id)
            let job = try await APIClient.shared.request(
                endpoint: .createGenerationJob,
                body: body,
                responseType: GenerationJobResponse.self
            )
            coordinator?.showResults(persona: persona, bundle: bundle, jobId: job.id)
        } catch APIError.serverError(409, _) {
            // Already in progress — go to results to poll existing job
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
                loadBundles()
                onPurchaseComplete?(bundle)
                await startGeneration(bundle: bundle)
            }
        } catch {
            onError?("Purchase failed: \(error.localizedDescription)")
        }
    }

    // Overlay blocks style selection only while training is actively running.
    // draft = photos stored, ready for style tap; processing = training in flight.
    var isProcessing: Bool { persona.status == .processing || persona.status == .uploading }
}
