import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    if let windowScene = scene as? UIWindowScene {
      let appRepository = appDelegate.appRepository
      let lookupService = appDelegate.appStore
      let settings = appDelegate.settings

      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = UIHostingController(
        rootView: AppListView()
          .environmentObject(AppListViewModel(appRepository: appRepository, lookupService: lookupService, settings: settings))
          .environmentObject(settings)
      )
      self.window = window
      window.makeKeyAndVisible()
    }

    if let urlContext = connectionOptions.urlContexts.first {
      handleURLScheme(urlContext.url)
    }
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    appDelegate.wishlistUpdater.performPeriodicUpdate()
  }

  func sceneDidEnterBackground(_ scene: UIScene) {
    appDelegate.scheduleAppRefresh()
  }

  func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
    if let urlContext = urlContexts.first {
      handleURLScheme(urlContext.url)
    }
  }

  private func handleURLScheme(_ url: URL) {
    guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true), let action = components.host else {
      print("Invalid URL or action is missing")
      return
    }

    switch action {
    case "add":
      if let appIDs = components.queryItems?.first(where: { $0.name == "id" })?.value {
        let ids = appIDs.split(separator: ",").compactMap { Int($0, radix: 10) }
        guard !ids.isEmpty else {
          return
        }
        print("Adding ids: \(ids)")
        appDelegate.wishlistAdder.addApps(ids: ids)
      } else {
        print("Add action requires a list of comma separated app IDs.")
      }
    case "export":
      do {
        let ids = try appDelegate.appRepository.fetchAll().map { String($0.id) }.joined(separator: ",")
        print("appdates://add?id=\(ids)")
      } catch {
        print("Unable to export apps")
      }
    default:
      print("Unhandled URL scheme action: \(action)")
    }
  }

  private var appDelegate: AppDelegate {
    UIApplication.shared.delegate as! AppDelegate
  }
}
