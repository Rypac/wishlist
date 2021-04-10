import Domain
import Foundation
import Services
import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
  let settings = Settings()
  let appAdder: AppAdder
  let updateChecker: UpdateChecker
  let urlSchemeHandler: URLSchemeHandler
  let appRepository: AppRepository = {
    let path = FileManager.default.storeURL(for: "group.wishlist.database", databaseName: "Wishlist")
    let persistence = try! SQLiteAppPersistence(sqlite: SQLite(path: path.absoluteString))
    return AppRepository(persistence: persistence)
  }()

  override init() {
    let appStore: AppLookupService = AppStoreService()
    appAdder = AppAdder(
      environment: .live(
        AppAdder.Environment(
          loadApps: appStore.lookup,
          saveApps: appRepository.saveApps
        )
      )
    )
    updateChecker = UpdateChecker(
      environment: .live(
        UpdateChecker.Environment(
          apps: appRepository.appsPublisher,
          lookupApps: appStore.lookup,
          saveApps: appRepository.saveApps,
          lastUpdateDate: settings.$lastUpdateDate,
          updateFrequency: 5 * 60
        )
      )
    )
    urlSchemeHandler = URLSchemeHandler(
      environment: URLSchemeHandler.Environment(
        addApps: appAdder.addApps,
        deleteAllApps: appRepository.deleteAllApps
      )
    )
  }

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    settings.register()
    try? appRepository.refresh()

    return true
  }
}
