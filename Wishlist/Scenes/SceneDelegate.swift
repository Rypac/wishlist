import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    if let windowScene = scene as? UIWindowScene, let appDelegate = UIApplication.shared.delegate as? AppDelegate {
      let wishlist = appDelegate.wishlist
      let settings = appDelegate.settings

      appDelegate.persistentContainer.viewContext.automaticallyMergesChangesFromParent = true

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
}
