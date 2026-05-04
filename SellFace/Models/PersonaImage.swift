import Foundation

struct PersonaImage: Identifiable, Codable {
    var id: String
    var personaId: String
    var localPath: String?
    var remoteURL: String?
    var uploadedAt: Date?

    init(id: String = UUID().uuidString, personaId: String, localPath: String? = nil) {
        self.id = id
        self.personaId = personaId
        self.localPath = localPath
    }
}
