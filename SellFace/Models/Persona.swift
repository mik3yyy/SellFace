import Foundation

enum PersonaStatus: String, Codable {
    case draft
    case uploading
    case processing
    case ready
    case failed
}

struct Persona: Identifiable, Codable {
    var id: String
    var name: String
    var coverImageURL: String?
    var localCoverImagePath: String?
    var status: PersonaStatus
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, status: PersonaStatus = .draft, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.status = status
        self.createdAt = createdAt
    }
}
