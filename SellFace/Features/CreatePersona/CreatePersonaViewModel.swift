import UIKit

@MainActor
final class CreatePersonaViewModel {
    weak var coordinator: AppCoordinator?

    private(set) var selectedImages: [UIImage] = []
    private(set) var isCreating = false

    var onImagesUpdated: (() -> Void)?
    var onProgress: ((Int, Int) -> Void)?       // (uploaded, total)
    var onCreationComplete: ((Persona) -> Void)?
    var onError: ((String) -> Void)?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    func addImages(_ images: [UIImage]) {
        selectedImages = Array((selectedImages + images).prefix(15))
        onImagesUpdated?()
    }

    func didSelectImages(_ images: [UIImage]) {
        selectedImages = images
        onImagesUpdated?()
    }

    func createPersona(name: String, gender: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            onError?("Please enter a name for this persona.")
            return
        }
        guard selectedImages.count >= 10 else {
            onError?("Please select at least 10 photos.")
            return
        }
        guard !isCreating else { return }

        isCreating = true

        let subjectKeyword = gender.lowercased() == "male" ? "man" : "woman"

        Task {
            do {
                // Step 1: Create the persona record
                let personaResponse = try await APIClient.shared.request(
                    endpoint: .createPersona,
                    body: CreatePersonaBody(name: trimmedName, subjectKeyword: subjectKeyword),
                    responseType: PersonaResponse.self
                )

                // Step 2: Upload photos one at a time — each request is small and fast
                let total = selectedImages.count
                for (index, image) in selectedImages.enumerated() {
                    guard let jpeg = image.jpegData(compressionQuality: 0.75) else { continue }

                    var form = MultipartFormData()
                    form.append(data: jpeg, name: "files", filename: "photo_\(index).jpg", mimeType: "image/jpeg")

                    _ = try await APIClient.shared.upload(
                        endpoint: .uploadPersonaImages(personaId: personaResponse.id),
                        multipartData: form
                    )

                    onProgress?(index + 1, total)
                }

                // Step 3: Save first photo locally as cover thumbnail
                var persona = personaResponse.toPersona()
                if let first = selectedImages.first {
                    let path = ImageStorageManager.shared.save(
                        image: first,
                        forPersonaId: persona.id,
                        imageId: "cover"
                    )
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
