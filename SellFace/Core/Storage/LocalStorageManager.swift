import Foundation

final class LocalStorageManager {
    static let shared = LocalStorageManager()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let personas          = "sf_personas"
        static let userIdentity      = "sf_user_identity"
        static let generationJobs    = "sf_generation_jobs"
        static let unlockedBundles   = "sf_unlocked_bundles"
        static let generatedPersonas = "sf_generated_personas"
        static let activeJobs        = "sf_active_jobs"
    }

    private init() {}

    // MARK: - UserIdentity

    func saveUserIdentity(_ identity: UserIdentity) {
        if let data = try? encoder.encode(identity) {
            defaults.set(data, forKey: Key.userIdentity)
        }
    }

    func loadUserIdentity() -> UserIdentity? {
        guard let data = defaults.data(forKey: Key.userIdentity) else { return nil }
        return try? decoder.decode(UserIdentity.self, from: data)
    }

    // MARK: - Personas

    func savePersonas(_ personas: [Persona]) {
        if let data = try? encoder.encode(personas) {
            defaults.set(data, forKey: Key.personas)
        }
    }

    func loadPersonas() -> [Persona] {
        guard let data = defaults.data(forKey: Key.personas) else { return [] }
        return (try? decoder.decode([Persona].self, from: data)) ?? []
    }

    func savePersona(_ persona: Persona) {
        var all = loadPersonas()
        if let idx = all.firstIndex(where: { $0.id == persona.id }) {
            all[idx] = persona
        } else {
            all.append(persona)
        }
        savePersonas(all)
    }

    func deletePersona(id: String) {
        var all = loadPersonas()
        all.removeAll { $0.id == id }
        savePersonas(all)
    }

    // MARK: - Generation Jobs

    func saveGenerationJob(_ job: GenerationJob) {
        var all = loadGenerationJobs()
        if let idx = all.firstIndex(where: { $0.id == job.id }) {
            all[idx] = job
        } else {
            all.append(job)
        }
        if let data = try? encoder.encode(all) {
            defaults.set(data, forKey: Key.generationJobs)
        }
    }

    func loadGenerationJobs() -> [GenerationJob] {
        guard let data = defaults.data(forKey: Key.generationJobs) else { return [] }
        return (try? decoder.decode([GenerationJob].self, from: data)) ?? []
    }

    func jobsForPersona(id: String) -> [GenerationJob] {
        loadGenerationJobs().filter { $0.personaId == id }
    }

    // MARK: - Unlocked Bundles

    func saveUnlockedBundles(_ productIds: Set<String>) {
        defaults.set(Array(productIds), forKey: Key.unlockedBundles)
    }

    func loadUnlockedBundles() -> Set<String> {
        let arr = defaults.stringArray(forKey: Key.unlockedBundles) ?? []
        return Set(arr)
    }

    func unlockBundle(productId: String) {
        var current = loadUnlockedBundles()
        current.insert(productId)
        saveUnlockedBundles(current)
    }

    // MARK: - Per-persona generation tracking

    func markPersonaAsGenerated(_ personaId: String) {
        var ids = Set(defaults.stringArray(forKey: Key.generatedPersonas) ?? [])
        ids.insert(personaId)
        defaults.set(Array(ids), forKey: Key.generatedPersonas)
    }

    func hasGeneratedBundle(forPersonaId personaId: String) -> Bool {
        let ids = Set(defaults.stringArray(forKey: Key.generatedPersonas) ?? [])
        return ids.contains(personaId)
    }

    // MARK: - Active job tracking (persists shimmer across app restarts)

    func storeActiveJob(personaId: String, bundleId: String, jobId: String) {
        var jobs = activeJobs()
        jobs[personaId] = ["bundleId": bundleId, "jobId": jobId]
        defaults.set(jobs, forKey: Key.activeJobs)
    }

    func activeJob(forPersonaId personaId: String) -> (bundleId: String, jobId: String)? {
        guard let entry = activeJobs()[personaId],
              let bundleId = entry["bundleId"],
              let jobId    = entry["jobId"] else { return nil }
        return (bundleId, jobId)
    }

    func clearActiveJob(forPersonaId personaId: String) {
        var jobs = activeJobs()
        jobs.removeValue(forKey: personaId)
        defaults.set(jobs, forKey: Key.activeJobs)
    }

    private func activeJobs() -> [String: [String: String]] {
        defaults.dictionary(forKey: Key.activeJobs) as? [String: [String: String]] ?? [:]
    }
}
