import Combine
import Domain
import Foundation
import Services
import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
  let settings = Settings()
  let appRepository: AppRepository
  let appAdder: AppAdder
  let updateChecker: UpdateChecker
  let urlSchemeHandler: URLSchemeHandler
  let reactiveEnvironment: ReactiveAppEnvironment

  override init() {
    let appStore: AppLookupService = AppStoreService()
    let path = FileManager.default.storeURL(for: "group.wishlist.database", databaseName: "Wishlist")
    appRepository = try! SQLiteAppRepository(sqlite: SQLite(path: path.absoluteString))
    reactiveEnvironment = ReactiveAppEnvironment(repository: appRepository)
    appAdder = AppAdder(
      environment: .live(
        AppAdder.Environment(
          loadApps: appStore.lookup,
          saveApps: reactiveEnvironment.saveApps
        )
      )
    )
    updateChecker = UpdateChecker(
      environment: .live(
        UpdateChecker.Environment(
          apps: reactiveEnvironment.appsPublisher,
          lookupApps: appStore.lookup,
          saveApps: reactiveEnvironment.saveApps,
          lastUpdateDate: settings.$lastUpdateDate,
          updateFrequency: 5 * 60
        )
      )
    )
    urlSchemeHandler = URLSchemeHandler(
      environment: URLSchemeHandler.Environment(
        addApps: appAdder.addApps,
        deleteAllApps: reactiveEnvironment.deleteAllApps
      )
    )
  }

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    settings.register()
    try? reactiveEnvironment.refresh()

    return true
  }
}
