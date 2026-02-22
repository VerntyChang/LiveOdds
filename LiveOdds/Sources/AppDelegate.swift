import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window

        let apiService = MockAPIService()
        let webSocketService = MockWebSocketService()
        let viewModel = MatchListViewModel(apiService: apiService, webSocketService: webSocketService)
        let viewController = MatchListViewController(viewModel: viewModel)
        let navigationController = UINavigationController(rootViewController: viewController)

        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        return true
    }
}
