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
        let tagline = StyleBundle.staticMetadata.first(where: { $0.id == id })?.tagline ?? ""
        return StyleBundle(
            id: id,
            name: name,
            description: description,
            tagline: tagline,
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
    let phase: String?           // "training" | "generating" | "completed" | "failed"
    let personaId: String
    let styleBundleId: String
    let generatedImages: [GeneratedImageResponse]?
}

struct GeneratedImageResponse: Codable {
    let id: String
    let imageUrl: String
}

struct DeviceTokenRequest: Encodable {
    let token: String
    let platform: String = "ios"
}

struct EmptyResponse: Decodable {}
