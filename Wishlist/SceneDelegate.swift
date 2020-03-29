import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
    // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
    // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

    // Use a UIHostingController as window root view controller.
    if let windowScene = scene as? UIWindowScene, let appDelegate = UIApplication.shared.delegate as? AppDelegate {
      let wishlist = appDelegate.wishlist
      let settings = appDelegate.settings
      let appStoreService = AppStoreService()

      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = UIHostingController(
        rootView: AppListView()
          .environmentObject(AppListViewModel(wishlist: wishlist, settings: settings, appStoreService: appStoreService))
          .environmentObject(settings)
      )
      self.window = window
      window.makeKeyAndVisible()
    }
  }
}
