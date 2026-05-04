import UIKit

@MainActor
final class ResultsViewModel {
    let persona: Persona
    let bundle: StyleBundle
    let jobId: String?

    private(set) var images: [UIImage] = []
    private(set) var isLoading = true
    private(set) var statusMessage = "Generating your AI headshots..."

    var onStateChanged: (() -> Void)?
    var onImagesLoaded: (() -> Void)?

    init(persona: Persona, bundle: StyleBundle, jobId: String? = nil) {
        self.persona = persona
        self.bundle = bundle
        self.jobId = jobId
    }

    func loadImages() {
        isLoading = true
        statusMessage = "Generating your AI headshots..."
        onStateChanged?()

        Task {
            if let jobId {
                await pollJob(jobId: jobId)
            } else {
                await fetchExistingResults()
            }
        }
    }

    // Poll GET /generation-jobs/{id} every 10s until completed or failed
    private func pollJob(jobId: String) async {
        for _ in 0..<60 {  // up to 10 minutes
            do {
                let job = try await APIClient.shared.request(
                    endpoint: .getGenerationJob(id: jobId),
                    responseType: GenerationJobResponse.self
                )

                switch job.status {
                case "completed":
                    let imageUrls = (job.generatedImages ?? []).map { $0.imageUrl }
                    if imageUrls.isEmpty {
                        await fetchExistingResults()
                    } else {
                        await loadFrom(urls: imageUrls)
                    }
                    return

                case "failed":
                    isLoading = false
                    statusMessage = "Generation failed. Please try again."
                    onStateChanged?()
                    return

                default:
                    statusMessage = "Generating your AI headshots..."
                    onStateChanged?()
                }
            } catch {
                // Network hiccup — keep polling
            }

            try? await Task.sleep(for: .seconds(10))
        }

        isLoading = false
        statusMessage = "This is taking longer than usual. Check back soon."
        onStateChanged?()
    }

    // Fetch already-completed results for this persona + style
    private func fetchExistingResults() async {
        do {
            let results = try await APIClient.shared.request(
                endpoint: .getPersonaResults(personaId: persona.id, styleBundleId: bundle.id),
                responseType: [GeneratedImageResponse].self
            )
            if results.isEmpty {
                isLoading = false
                statusMessage = "No headshots yet. Generation may still be in progress."
                onStateChanged?()
            } else {
                await loadFrom(urls: results.map { $0.imageUrl })
            }
        } catch {
            isLoading = false
            statusMessage = "Could not load images. Check your connection."
            onStateChanged?()
        }
    }

    // Download UIImages from a list of URLs
    private func loadFrom(urls: [String]) async {
        var loaded: [UIImage] = []
        await withTaskGroup(of: UIImage?.self) { group in
            for urlString in urls {
                guard let url = URL(string: urlString) else { continue }
                group.addTask {
                    guard let data = try? await APIClient.shared.downloadData(from: url) else { return nil }
                    return UIImage(data: data)
                }
            }
            for await image in group {
                if let image { loaded.append(image) }
            }
        }
        images = loaded
        isLoading = loaded.isEmpty
        statusMessage = loaded.isEmpty ? "No images available yet." : ""
        onStateChanged?()
        onImagesLoaded?()
    }
}
