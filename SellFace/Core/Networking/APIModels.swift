import Foundation

// MARK: - Request Bodies

struct CreatePersonaBody: Encodable {
    let name: String
    let subjectKeyword: String
}

struct CreateGenerationJobBody: Encodable {
    let personaId: String
    let styleBundleId: String
}

// MARK: - Response Types

struct PersonaResponse: Codable {
    let id: String
    let name: String
    let status: String
    let coverImageUrl: String?
    let imageCount: Int
    let createdAt: Date

    func toPersona() -> Persona {
        var p = Persona(id: id, name: name, status: PersonaStatus(rawValue: status) ?? .draft, createdAt: createdAt)
        p.coverImageURL = coverImageUrl
        return p
    }
}

struct StyleBundleResponse: Codable {
    let id: String
    let name: String
    let description: String
    let productId: String
    let price: String
    let oldPrice: String?
    let previewImageName: String
    let isActive: Bool
    let sortOrder: Int

    func toStyleBundle(unlocked: Bool) -> StyleBundle {
        StyleBundle(
            id: id,
            name: name,
            description: description,
            productId: productId,
            price: price,
            oldPrice: oldPrice,
            previewImageName: previewImageName,
            isUnlocked: unlocked
        )
    }
}

struct GenerationJobResponse: Codable {
    let id: String
    let status: String
    let personaId: String
    let styleBundleId: String
    let generatedImages: [GeneratedImageResponse]?
}

struct GeneratedImageResponse: Codable {
    let id: String
    let imageUrl: String
}
