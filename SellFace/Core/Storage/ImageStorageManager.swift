import UIKit

final class ImageStorageManager {
    static let shared = ImageStorageManager()

    private let fileManager = FileManager.default
    private var imagesDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("SellFaceImages", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private init() {}

    func save(image: UIImage, forPersonaId personaId: String, imageId: String) -> String? {
        let personaDir = imagesDirectory.appendingPathComponent(personaId, isDirectory: true)
        if !fileManager.fileExists(atPath: personaDir.path) {
            try? fileManager.createDirectory(at: personaDir, withIntermediateDirectories: true)
        }
        let fileURL = personaDir.appendingPathComponent("\(imageId).jpg")
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        try? data.write(to: fileURL)
        return fileURL.path
    }

    func load(fromPath path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }

    func imagesForPersona(id: String) -> [UIImage] {
        let personaDir = imagesDirectory.appendingPathComponent(id, isDirectory: true)
        guard let files = try? fileManager.contentsOfDirectory(atPath: personaDir.path) else { return [] }
        return files.compactMap { UIImage(contentsOfFile: personaDir.appendingPathComponent($0).path) }
    }

    func deleteImages(forPersonaId personaId: String) {
        let personaDir = imagesDirectory.appendingPathComponent(personaId, isDirectory: true)
        try? fileManager.removeItem(at: personaDir)
    }

    // TODO: Implement Cloudinary upload when backend credentials are available
    func uploadToCloudinary(image: UIImage, personaId: String) async throws -> String {
        // TODO: Replace with real Cloudinary upload
        // Cloudinary URL: https://api.cloudinary.com/v1_1/{cloud_name}/image/upload
        // Requires: cloud_name, upload_preset or API key/secret
        throw APIError.mockMode
    }

    func prepareImagesForUpload(personaId: String) -> [Data] {
        imagesForPersona(id: personaId).compactMap { $0.jpegData(compressionQuality: 0.8) }
    }
}
