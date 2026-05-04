import Foundation

enum GenerationStatus: String, Codable {
    case queued
    case processing
    case completed
    case failed
}

struct GenerationJob: Identifiable, Codable {
    var id: String
    var personaId: String
    var styleBundleId: String
    var status: GenerationStatus
    var createdAt: Date
    var completedAt: Date?

    init(id: String = UUID().uuidString, personaId: String, styleBundleId: String, status: GenerationStatus = .queued, createdAt: Date = Date()) {
        self.id = id
        self.personaId = personaId
        self.styleBundleId = styleBundleId
        self.status = status
        self.createdAt = createdAt
    }
}
