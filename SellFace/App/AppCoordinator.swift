import UIKit

@MainActor
final class AppCoordinator {
    let navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        navigationController.applyDarkGoldStyle()
        setupUserIdentity()
        showPersonas()
        Task { await NotificationManager.shared.requestPermission() }
        Task { await StoreKitManager.shared.updatePurchasedProducts() }
        NotificationManager.shared.onNotificationTap = { [weak self] jobId in
            self?.handleNotificationTap(jobId: jobId)
        }
    }

    private func setupUserIdentity() {
        if LocalStorageManager.shared.loadUserIdentity() == nil {
            let identity = UserIdentity()
            LocalStorageManager.shared.saveUserIdentity(identity)
            Task {
                if await CloudKitManager.shared.isAvailable {
                    if let ckId = try? await CloudKitManager.shared.getCurrentUserRecordID() {
                        var updated = identity
                        updated.cloudKitRecordID = ckId
                        LocalStorageManager.shared.saveUserIdentity(updated)
                        try? await CloudKitManager.shared.saveUserIdentity(updated)
                    }
                }
            }
        }
    }

    func showPersonas() {
        let vm = PersonasViewModel(coordinator: self)
        let vc = PersonasViewController(viewModel: vm)
        navigationController.setViewControllers([vc], animated: false)
    }

    func showCreatePersona() {
        let vm = CreatePersonaViewModel(coordinator: self)
        let vc = CreatePersonaViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    func showPersonaDetail(_ persona: Persona) {
        let vm = PersonaDetailViewModel(persona: persona, coordinator: self)
        let vc = PersonaDetailViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    func showPersonaDetailAfterCreation(_ persona: Persona) {
        let personasVM = PersonasViewModel(coordinator: self)
        let personasVC = PersonasViewController(viewModel: personasVM)
        let detailVM = PersonaDetailViewModel(persona: persona, coordinator: self)
        let detailVC = PersonaDetailViewController(viewModel: detailVM)
        navigationController.setViewControllers([personasVC, detailVC], animated: true)
    }

    func showResults(persona: Persona, bundle: StyleBundle, jobId: String? = nil, estimatedMinutes: Int = 5) {
        let vm = ResultsViewModel(persona: persona, bundle: bundle, jobId: jobId, estimatedMinutes: estimatedMinutes)
        let vc = ResultsViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
    }

    // Called when user taps a "photos ready" push notification
    func handleNotificationTap(jobId: String) {
        Task {
            do {
                let job = try await APIClient.shared.request(
                    endpoint: .getGenerationJob(id: jobId),
                    responseType: GenerationJobResponse.self
                )
                let personaResponse = try await APIClient.shared.request(
                    endpoint: .getPersona(id: job.personaId),
                    responseType: PersonaResponse.self
                )
                let persona = personaResponse.toPersona()

                let bundles = try await APIClient.shared.request(
                    endpoint: .getStyles,
                    responseType: [StyleBundleResponse].self
                )
                guard let bundleResponse = bundles.first(where: { $0.id == job.styleBundleId }) else {
                    showPersonaDetail(persona)
                    return
                }
                let bundle = bundleResponse.toStyleBundle(unlocked: true)

                let personasVM = PersonasViewModel(coordinator: self)
                let personasVC = PersonasViewController(viewModel: personasVM)
                let detailVM = PersonaDetailViewModel(persona: persona, coordinator: self)
                let detailVC = PersonaDetailViewController(viewModel: detailVM)
                let resultsVM = ResultsViewModel(persona: persona, bundle: bundle, jobId: jobId, estimatedMinutes: 5)
                let resultsVC = ResultsViewController(viewModel: resultsVM)
                navigationController.setViewControllers([personasVC, detailVC, resultsVC], animated: true)
            } catch {
                // Network failed — just go to personas root so user can navigate manually
                showPersonas()
            }
        }
    }

    func showHelp(from vc: UIViewController) {
        let helpVC = HelpViewController()
        let nav = UINavigationController(rootViewController: helpVC)
        nav.applyDarkGoldStyle()
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = SFSpacing.cardRadius
        }
        vc.present(nav, animated: true)
    }
}
