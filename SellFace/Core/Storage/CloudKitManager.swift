import CloudKit
import Foundation

final class CloudKitManager {
    static let shared = CloudKitManager()

    private let container = CKContainer.default()
    private var database: CKDatabase { container.privateCloudDatabase }

    private enum RecordType {
        static let userIdentity = "UserIdentity"
        static let persona = "Persona"
    }

    private init() {}

    var isAvailable: Bool {
        get async {
            do {
                let status = try await container.accountStatus()
                return status == .available
            } catch {
                return false
            }
        }
    }

    func getCurrentUserRecordID() async throws -> String {
        let recordID = try await container.userRecordID()
        return recordID.recordName
    }

    func saveUserIdentity(_ identity: UserIdentity) async throws {
        let recordID = CKRecord.ID(recordName: identity.id)
        let record = CKRecord(recordType: RecordType.userIdentity, recordID: recordID)
        record["userId"] = identity.id as CKRecordValue
        record["createdAt"] = identity.createdAt as CKRecordValue
        if let ckid = identity.cloudKitRecordID {
            record["cloudKitRecordID"] = ckid as CKRecordValue
        }
        try await database.save(record)
    }

    func fetchUserIdentity(id: String) async throws -> UserIdentity? {
        let recordID = CKRecord.ID(recordName: id)
        let record = try await database.record(for: recordID)
        guard let userId = record["userId"] as? String,
              let createdAt = record["createdAt"] as? Date else { return nil }
        let ckid = record["cloudKitRecordID"] as? String
        return UserIdentity(id: userId, cloudKitRecordID: ckid, createdAt: createdAt)
    }

    func savePersonaMetadata(_ persona: Persona) async throws {
        let recordID = CKRecord.ID(recordName: persona.id)
        let record = CKRecord(recordType: RecordType.persona, recordID: recordID)
        record["name"] = persona.name as CKRecordValue
        record["status"] = persona.status.rawValue as CKRecordValue
        record["createdAt"] = persona.createdAt as CKRecordValue
        if let url = persona.coverImageURL {
            record["coverImageURL"] = url as CKRecordValue
        }
        try await database.save(record)
    }

    func fetchPersonas() async throws -> [Persona] {
        let query = CKQuery(recordType: RecordType.persona, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        let result = try await database.records(matching: query)
        return result.matchResults.compactMap { _, outcome -> Persona? in
            guard let record = try? outcome.get(),
                  let name = record["name"] as? String,
                  let statusRaw = record["status"] as? String,
                  let status = PersonaStatus(rawValue: statusRaw),
                  let createdAt = record["createdAt"] as? Date else { return nil }
            var p = Persona(id: record.recordID.recordName, name: name, status: status, createdAt: createdAt)
            p.coverImageURL = record["coverImageURL"] as? String
            return p
        }
    }
}
