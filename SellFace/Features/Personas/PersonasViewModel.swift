import Foundation
import UIKit

@MainActor
final class PersonasViewModel {
    weak var coordinator: AppCoordinator?

    private(set) var personas: [Persona] = []
    private(set) var isLoading = false
    var onPersonasUpdated: (() -> Void)?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    func loadPersonas() {
        isLoading = true
        personas = LocalStorageManager.shared.loadPersonas()
            .sorted { $0.createdAt > $1.createdAt }
        onPersonasUpdated?()
        Task { await fetchFromBackend() }
    }

    private func fetchFromBackend() async {
        do {
            let responses = try await APIClient.shared.request(
                endpoint: .getPersonas,
                responseType: [PersonaResponse].self
            )
            let fresh = responses.map { $0.toPersona() }.sorted { $0.createdAt > $1.createdAt }
            let cached = LocalStorageManager.shared.loadPersonas()
            personas = fresh.map { p in
                var updated = p
                if let local = cached.first(where: { $0.id == p.id }) {
                    updated.localCoverImagePath = local.localCoverImagePath
                }
                return updated
            }
            LocalStorageManager.shared.savePersonas(personas)
        } catch {}
        isLoading = false
        onPersonasUpdated?()
    }

    func deletePersona(at index: Int) {
        let persona = personas[index]
        personas.remove(at: index)
        LocalStorageManager.shared.deletePersona(id: persona.id)
        ImageStorageManager.shared.deleteImages(forPersonaId: persona.id)
        onPersonasUpdated?()
    }

    func didTapPersona(_ persona: Persona) {
        coordinator?.showPersonaDetail(persona)
    }

    func didTapCreate() {
        coordinator?.showCreatePersona()
    }

    func didTapHelp(from vc: UIViewController) {
        coordinator?.showHelp(from: vc)
    }
}
