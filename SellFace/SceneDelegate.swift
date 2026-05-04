import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var coordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let nav = UINavigationController()
        nav.navigationBar.prefersLargeTitles = true
        nav.navigationBar.tintColor = SFColors.accent

        let coordinator = AppCoordinator(navigationController: nav)
        self.coordinator = coordinator

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = nav
        window?.makeKeyAndVisible()

        coordinator.start()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }
}
