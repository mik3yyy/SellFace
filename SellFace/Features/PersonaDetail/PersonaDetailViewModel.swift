import Foundation
import StoreKit

@MainActor
final class PersonaDetailViewModel {
    private(set) var persona: Persona
    weak var coordinator: AppCoordinator?

    private(set) var styleBundles: [StyleBundle] = []
    private(set) var generatingBundleId: String?

    // Per-persona: true only after this persona has had at least one bundle generated
    var hasGeneratedAnyBundle: Bool {
        LocalStorageManager.shared.hasGeneratedBundle(forPersonaId: persona.id)
    }

    var onBundlesUpdated: (() -> Void)?
    var onPurchaseComplete: ((StyleBundle) -> Void)?
    var onError: ((String) -> Void)?

    init(persona: Persona, coordinator: AppCoordinator) {
        self.persona = persona
        self.coordinator = coordinator
        // Restore shimmer if a job was in progress when app was last open
        if let (bundleId, jobId) = LocalStorageManager.shared.activeJob(forPersonaId: persona.id) {
            generatingBundleId = bundleId
            Task { await pollUntilComplete(jobId: jobId) }
        }
    }

    // MARK: - Bundle loading (StoreKit only)

    func loadBundles() {
        // Re-sync generating state from LocalStorage — covers the case where the user
        // backgrounds the app, relaunches, or viewWillAppear fires on an existing VM instance.
        if generatingBundleId == nil,
           let (bundleId, jobId) = LocalStorageManager.shared.activeJob(forPersonaId: persona.id) {
            generatingBundleId = bundleId
            Task { await pollUntilComplete(jobId: jobId) }
        }

        let products = StoreKitManager.shared.products
        if products.isEmpty {
            styleBundles = []
            onBundlesUpdated?()
            Task {
                await StoreKitManager.shared.loadProducts()
                buildBundlesFromStoreKit()
                await fetchBundlePreviews()
            }
        } else {
            buildBundlesFromStoreKit()
            Task { await fetchBundlePreviews() }
        }
    }

    private func fetchBundlePreviews() async {
        guard hasGeneratedAnyBundle else { return }
        await withTaskGroup(of: (Int, String?).self) { group in
            for i in styleBundles.indices {
                let productId = styleBundles[i].productId
                let personaId = persona.id
                group.addTask {
                    let results = try? await APIClient.shared.request(
                        endpoint: .getPersonaResults(personaId: personaId, styleBundleId: productId),
                        responseType: [GeneratedImageResponse].self
                    )
                    return (i, results?.first?.imageUrl)
                }
            }
            for await (i, url) in group {
                styleBundles[i].previewImageUrl = url
                styleBundles[i].isCheckingPreview = false
                onBundlesUpdated?()
            }
        }
    }

    private func buildBundlesFromStoreKit() {
        let products = StoreKitManager.shared.products
        let unlocked = StoreKitManager.shared.purchasedProductIDs
        let checkPreviews = hasGeneratedAnyBundle

        styleBundles = products.compactMap { product -> StyleBundle? in
            guard let meta = StyleBundle.staticMetadata.first(where: { $0.productId == product.id }) else { return nil }

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
                tagline: meta.tagline,
                productId: product.id,
                price: product.displayPrice,
                oldPrice: oldPrice,
                previewImageName: meta.previewImageName,
                isUnlocked: unlocked.contains(product.id),
                isCheckingPreview: checkPreviews  // show shimmer immediately for returning users
            )
        }
        onBundlesUpdated?()
    }

    // MARK: - Bundle interaction

    func didTapBundle(_ bundle: StyleBundle) {
        // Always go through purchase — Apple handles free restore if already bought
        Task { await purchaseBundle(bundle) }
    }

    private func startGeneration(bundle: StyleBundle) async {
        // Check for already-completed results first — avoids creating a redundant Astria job
        if let existingImages = try? await APIClient.shared.request(
            endpoint: .getPersonaResults(personaId: persona.id, styleBundleId: bundle.productId),
            responseType: [GeneratedImageResponse].self
        ), !existingImages.isEmpty {
            coordinator?.showResults(persona: persona, bundle: bundle, jobId: nil, estimatedMinutes: 0)
            return
        }

        let isFirst = !hasGeneratedAnyBundle
        let estimatedMinutes = isFirst ? 25 : 5

        generatingBundleId = bundle.id
        onBundlesUpdated?()
        do {
            let body = CreateGenerationJobBody(personaId: persona.id, styleBundleId: bundle.productId)
            let job = try await APIClient.shared.request(
                endpoint: .createGenerationJob,
                body: body,
                responseType: GenerationJobResponse.self
            )
            LocalStorageManager.shared.markPersonaAsGenerated(persona.id)
            LocalStorageManager.shared.storeActiveJob(personaId: persona.id, bundleId: bundle.id, jobId: job.id)
            coordinator?.showResults(persona: persona, bundle: bundle, jobId: job.id, estimatedMinutes: estimatedMinutes)
            Task { await pollUntilComplete(jobId: job.id) }
        } catch APIError.serverError(409, _) {
            LocalStorageManager.shared.markPersonaAsGenerated(persona.id)
            let existingJobId = LocalStorageManager.shared.activeJob(forPersonaId: persona.id)?.1
            generatingBundleId = existingJobId != nil ? bundle.id : nil
            onBundlesUpdated?()
            coordinator?.showResults(persona: persona, bundle: bundle, jobId: existingJobId, estimatedMinutes: estimatedMinutes)
        } catch {
            generatingBundleId = nil
            onBundlesUpdated?()
            onError?("Could not start generation: \(error.localizedDescription)")
        }
    }

    private func pollUntilComplete(jobId: String) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            guard let job = try? await APIClient.shared.request(
                endpoint: .getGenerationJob(id: jobId),
                responseType: GenerationJobResponse.self
            ) else { continue }
            if job.status == "completed" || job.status == "failed" {
                LocalStorageManager.shared.clearActiveJob(forPersonaId: persona.id)
                generatingBundleId = nil
                onBundlesUpdated?()
                return
            }
        }
    }

    private func purchaseBundle(_ bundle: StyleBundle) async {
        do {
            let success = try await StoreKitManager.shared.purchase(productId: bundle.productId)
            if success {
                await startGeneration(bundle: bundle)
            }
        } catch {
            onError?("Purchase failed: \(error.localizedDescription)")
        }
    }

    var isProcessing: Bool { persona.status == .processing || persona.status == .uploading }
}
