import UIKit

@MainActor
final class CreatePersonaViewModel {
    weak var coordinator: AppCoordinator?

    private(set) var selectedImages: [UIImage] = []
    private(set) var isCreating = false

    var onImagesUpdated: (() -> Void)?
    var onCreationComplete: ((Persona) -> Void)?
    var onError: ((String) -> Void)?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    func didSelectImages(_ images: [UIImage]) {
        selectedImages = images
        onImagesUpdated?()
    }

    func createPersona(name: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            onError?("Please enter a name for this persona.")
            return
        }
        guard selectedImages.count >= 10 else {
            onError?("Please select at least 10 photos.")
            return
        }
        guard !isCreating else { return }

        isCreating = true

        Task {
            do {
                // 1. Create persona on backend
                let body = CreatePersonaBody(name: name, subjectKeyword: "person")
                let personaResponse = try await APIClient.shared.request(
                    endpoint: .createPersona,
                    body: body,
                    responseType: PersonaResponse.self
                )

                // 2. Upload all images as multipart
                var form = MultipartFormData()
                for (i, image) in selectedImages.enumerated() {
                    guard let jpeg = image.jpegData(compressionQuality: 0.7) else { continue }
                    form.append(data: jpeg, name: "files", filename: "photo_\(i).jpg", mimeType: "image/jpeg")
                }
                _ = try await APIClient.shared.upload(
                    endpoint: .uploadPersonaImages(personaId: personaResponse.id),
                    multipartData: form
                )

                // 3. Save persona locally (backend kicks off training automatically)
                var persona = personaResponse.toPersona()
                // Save first image locally as cover thumbnail
                if let first = selectedImages.first {
                    let path = ImageStorageManager.shared.save(image: first, forPersonaId: persona.id, imageId: "cover")
                    persona.localCoverImagePath = path
                }
                LocalStorageManager.shared.savePersona(persona)

                isCreating = false
                onCreationComplete?(persona)

            } catch {
                isCreating = false
                onError?("Failed to create persona: \(error.localizedDescription)")
            }
        }
    }
}
