import UIKit

@MainActor
final class ResultsViewModel {
    let persona: Persona
    let bundle: StyleBundle
    let jobId: String?
    let estimatedMinutes: Int

    private(set) var images: [UIImage] = []
    private(set) var isLoading = true
    private(set) var statusMessage = ""
    private(set) var phase: String = "generating"  // "training" | "generating" | "completed" | "failed"

    var onStateChanged: (() -> Void)?
    var onImagesLoaded: (() -> Void)?

    init(persona: Persona, bundle: StyleBundle, jobId: String? = nil, estimatedMinutes: Int = 5) {
        self.persona = persona
        self.bundle = bundle
        self.jobId = jobId
        self.estimatedMinutes = estimatedMinutes
        statusMessage = "Generating your headshots…\n~\(estimatedMinutes) min"
    }

    func loadImages() {
        isLoading = true
        onStateChanged?()
        Task {
            if let jobId {
                await pollJob(jobId: jobId)
            } else {
                await fetchExistingResults()
            }
        }
    }

    // MARK: - Polling

    private func pollJob(jobId: String) async {
        // Poll up to 90 min — covers training (~20 min) + generation (~3 min)
        var attempt = 0
        while attempt < 360 {
            do {
                let job = try await APIClient.shared.request(
                    endpoint: .getGenerationJob(id: jobId),
                    responseType: GenerationJobResponse.self
                )
                let currentPhase = job.phase ?? (job.status == "completed" ? "completed" : "generating")
                phase = currentPhase
                updateStatusMessage(phase: currentPhase, attempt: attempt)
                onStateChanged?()

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
                    phase = "failed"
                    onStateChanged?()
                    return

                default:
                    break
                }
            } catch {
                // Network hiccup — keep polling
            }

            // Poll aggressively during generation (5s), slower during training (20s)
            let interval: UInt64 = (phase == "training") ? 20_000_000_000 : 5_000_000_000
            try? await Task.sleep(nanoseconds: interval)
            attempt += 1
        }

        isLoading = false
        statusMessage = "We'll send a notification when your photos are ready."
        onStateChanged?()
    }

    private func updateStatusMessage(phase: String, attempt: Int) {
        switch phase {
        case "training":
            if attempt == 0 {
                statusMessage = "Training your AI model…\n~20 min"
            } else if attempt < 6 {
                statusMessage = "Training your AI model…\nThis takes about 20 minutes"
            } else {
                statusMessage = "Still training…\nWe'll notify you when done — you can close the app"
            }
        case "generating":
            if attempt == 0 {
                statusMessage = "Generating your headshots…\n~3 min"
            } else {
                statusMessage = "Almost there…\nRendering your photos"
            }
        default:
            break
        }
    }

    // MARK: - Fetch already-completed results

    private func fetchExistingResults() async {
        do {
            let results = try await APIClient.shared.request(
                endpoint: .getPersonaResults(personaId: persona.id, styleBundleId: bundle.productId),
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

    // MARK: - Download UIImages

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
        phase = "completed"
        statusMessage = loaded.isEmpty ? "No images available yet." : ""
        onStateChanged?()
        onImagesLoaded?()
    }
}
