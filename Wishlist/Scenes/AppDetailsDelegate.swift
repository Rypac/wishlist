import SwiftUI
import UIKit
import WishlistData

class AppDetailsDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    if let windowScene = scene as? UIWindowScene, let appDelegate = UIApplication.shared.delegate as? AppDelegate {
      guard
        let id = session.userInfo?[ActivityIdentifier.UserInfoKey.id] as? Int,
        let app = try? appDelegate.appRepository.fetch(id: id)
      else {
        print("Attempted to show scene with invalid app id.")
        UIApplication.shared.requestSceneSessionDestruction(session, options: nil)
        return
      }

      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = UIHostingController(rootView: AppDetailsNavigationView(app: app, session: session))
      self.window = window
      window.makeKeyAndVisible()
    }
  }
}

private struct AppDetailsNavigationView: View {
  let app: App
  let session: UISceneSession

  var body: some View {
    NavigationView {
      AppDetailsContentView(app: app)
        .navigationBarTitle("Details", displayMode: .inline)
        .navigationBarItems(
          trailing: Button("Close") {
            UIApplication.shared.requestSceneSessionDestruction(self.session, options: nil)
          }.hoverEffect()
        )
    }.navigationViewStyle(StackNavigationViewStyle())
  }
}
