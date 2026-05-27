import UIKit
import StoreKit

@MainActor
final class PersonaDetailViewModel {
    private(set) var persona: Persona
    weak var coordinator: AppCoordinator?

    private(set) var styleBundles: [StyleBundle] = []
    private(set) var generatingBundleId: String?
    private var bundlePreviewImages: [String: UIImage] = [:]  // productId → UIImage (this VM instance)

    // Survives back-navigation and ViewModel recreation within the same app session
    private static var sessionImageCache: [String: (url: String, image: UIImage)] = [:]

    var hasGeneratedAnyBundle: Bool {
        LocalStorageManager.shared.hasGeneratedBundle(forPersonaId: persona.id)
    }

    var onBundlesUpdated: (() -> Void)?
    var onPurchaseComplete: ((StyleBundle) -> Void)?
    var onError: ((String) -> Void)?

    init(persona: Persona, coordinator: AppCoordinator) {
        self.persona = persona
        self.coordinator = coordinator
        if let (bundleId, jobId) = LocalStorageManager.shared.activeJob(forPersonaId: persona.id) {
            generatingBundleId = bundleId
            Task { await pollUntilComplete(jobId: jobId) }
        }
    }

    // MARK: - Bundle loading

    func loadBundles() {
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

    private func buildBundlesFromStoreKit() {
        let products = StoreKitManager.shared.products
        let unlocked = StoreKitManager.shared.purchasedProductIDs
        let completedIds = Set(persona.completedBundleProductIds)

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

            // Check session cache — if hit, set previewImageUrl immediately (no shimmer on re-navigation)
            let cacheKey = "\(persona.id)_\(product.id)"
            let cached = Self.sessionImageCache[cacheKey]
            bundlePreviewImages[product.id] = cached?.image

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
                previewImageUrl: cached?.url,
                isCheckingPreview: completedIds.contains(product.id) && cached == nil
            )
        }

        // Clear stale generating badge if the backend now reports this bundle as completed
        if let gid = generatingBundleId,
           let bundle = styleBundles.first(where: { $0.id == gid }),
           completedIds.contains(bundle.productId) {
            generatingBundleId = nil
            LocalStorageManager.shared.clearActiveJob(forPersonaId: persona.id)
        }

        onBundlesUpdated?()
    }

    func previewImage(for bundle: StyleBundle) -> UIImage? {
        bundlePreviewImages[bundle.productId]
    }

    private func fetchBundlePreviews() async {
        let indicesToFetch = styleBundles.indices.filter { styleBundles[$0].isCheckingPreview }
        guard !indicesToFetch.isEmpty else { return }

        await withTaskGroup(of: (Int, String?, UIImage?).self) { group in
            for i in indicesToFetch {
                let productId = styleBundles[i].productId
                let personaId = persona.id
                group.addTask {
                    let results = try? await APIClient.shared.request(
                        endpoint: .getPersonaResults(personaId: personaId, styleBundleId: productId),
                        responseType: [GeneratedImageResponse].self
                    )
                    guard let urlString = results?.first?.imageUrl,
                          let url = URL(string: urlString),
                          let data = try? await URLSession.shared.data(from: url).0,
                          let image = UIImage(data: data) else {
                        return (i, nil, nil)
                    }
                    return (i, urlString, image)
                }
            }
            for await (i, url, image) in group {
                let productId = styleBundles[i].productId
                styleBundles[i].previewImageUrl = url
                styleBundles[i].isCheckingPreview = false
                if let url, let image {
                    bundlePreviewImages[productId] = image
                    Self.sessionImageCache["\(persona.id)_\(productId)"] = (url: url, image: image)
                }
                onBundlesUpdated?()
            }
        }
    }

    // MARK: - Bundle interaction

    func didTapBundle(_ bundle: StyleBundle) {
        Task { await purchaseBundle(bundle) }
    }

    private func startGeneration(bundle: StyleBundle) async {
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
        // Check immediately first — no 30s wait if the job already finished before we got here
        while !Task.isCancelled {
            if let job = try? await APIClient.shared.request(
                endpoint: .getGenerationJob(id: jobId),
                responseType: GenerationJobResponse.self
            ), job.status == "completed" || job.status == "failed" {
                LocalStorageManager.shared.clearActiveJob(forPersonaId: persona.id)
                generatingBundleId = nil
                onBundlesUpdated?()
                if job.status == "completed" {
                    // Re-fetch persona to get updated completedBundleProductIds, then load images
                    await refreshPersonaAndPreviews()
                }
                return
            }
            try? await Task.sleep(for: .seconds(30))
        }
    }

    private func refreshPersonaAndPreviews() async {
        guard let response = try? await APIClient.shared.request(
            endpoint: .getPersona(id: persona.id),
            responseType: PersonaResponse.self
        ) else { return }
        persona = response.toPersona()
        buildBundlesFromStoreKit()
        await fetchBundlePreviews()
    }

    private func purchaseBundle(_ bundle: StyleBundle) async {
        do {
            let success = try await StoreKitManager.shared.purchase(productId: bundle.productId)
            if success { await startGeneration(bundle: bundle) }
        } catch {
            onError?("Purchase failed: \(error.localizedDescription)")
        }
    }

    var isProcessing: Bool { persona.status == .processing || persona.status == .uploading }
}
