import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    if let windowScene = scene as? UIWindowScene, let appDelegate = UIApplication.shared.delegate as? AppDelegate {
      let wishlist = appDelegate.wishlist
      let settings = appDelegate.settings

      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = UIHostingController(
        rootView: AppListView()
          .environmentObject(AppListViewModel(wishlist: wishlist, settings: settings))
          .environmentObject(settings)
      )
      self.window = window
      window.makeKeyAndVisible()
    }
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    checkForWishlistUpdates()
  }

  private func checkForWishlistUpdates() {
    if shouldUpdate {
      appDelegate.wishlistUpdater.performUpdate()
      appDelegate.settings.lastUpdateCheck = Date()
    }
  }

  private var shouldUpdate: Bool {
    guard let lastUpdateDate = appDelegate.settings.lastUpdateCheck else {
      return true
    }

    let now = Date()
    let oneMinute = 60
    let fiveMinutes = oneMinute * 5
    let timeSinceLastUpdate = now.timeIntervalSince(lastUpdateDate)

    return timeSinceLastUpdate > TimeInterval(fiveMinutes)
  }

  private var appDelegate: AppDelegate {
    UIApplication.shared.delegate as! AppDelegate
  }
}
