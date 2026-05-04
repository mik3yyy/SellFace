import Foundation

struct GeneratedImage: Identifiable, Codable {
    var id: String
    var jobId: String
    var imageURL: String
    var createdAt: Date

    init(id: String = UUID().uuidString, jobId: String, imageURL: String, createdAt: Date = Date()) {
        self.id = id
        self.jobId = jobId
        self.imageURL = imageURL
        self.createdAt = createdAt
    }
}
