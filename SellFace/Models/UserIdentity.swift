import Foundation

struct UserIdentity: Codable {
    var id: String
    var cloudKitRecordID: String?
    var createdAt: Date

    init(id: String = UUID().uuidString, cloudKitRecordID: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.cloudKitRecordID = cloudKitRecordID
        self.createdAt = createdAt
    }
}
