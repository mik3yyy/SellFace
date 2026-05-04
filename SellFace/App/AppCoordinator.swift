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

    func showResults(persona: Persona, bundle: StyleBundle, jobId: String? = nil) {
        let vm = ResultsViewModel(persona: persona, bundle: bundle, jobId: jobId)
        let vc = ResultsViewController(viewModel: vm)
        navigationController.pushViewController(vc, animated: true)
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
