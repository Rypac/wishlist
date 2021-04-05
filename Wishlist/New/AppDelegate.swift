import Combine
import Domain
import Foundation
import Services
import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
  let settings = Settings()
  let appStore: AppLookupService = AppStoreService()
  let appRepository: AppRepository
  let appAdder: AppAdder
  let updateChecker: UpdateChecker
  let urlSchemeHandler: URLSchemeHandler
  let reactiveEnvironment: ReactiveAppEnvironment

  override init() {
    let path = FileManager.default.storeURL(for: "group.wishlist.database", databaseName: "Wishlist")
    appRepository = try! SQLiteAppRepository(sqlite: SQLite(path: path.absoluteString))
    reactiveEnvironment = ReactiveAppEnvironment(repository: appRepository)
    appAdder = AppAdder(
      environment: .live(
        environment: AddAppsEnvironment(
          loadApps: appStore.lookup,
          saveApps: reactiveEnvironment.saveApps
        )
      )
    )
    updateChecker = UpdateChecker(
      environment: .live(
        environment: UpdateChecker.Environment(
          apps: reactiveEnvironment.appsPublisher,
          lookupApps: appStore.lookup,
          saveApps: reactiveEnvironment.saveApps,
          lastUpdateDate: settings.$lastUpdateDate,
          updateFrequency: 5 * 60
        )
      )
    )
    urlSchemeHandler = URLSchemeHandler(appAdder: appAdder)
  }

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    settings.register()
    registerBackgroundTasks()

    return true
  }

  // MARK: - Background Tasks

  private func registerBackgroundTasks() {
    // TODO: Reimplement background task handling
//    let registeredTask = BGTaskScheduler.shared.register(forTaskWithIdentifier: updateTask.id, using: nil) { task in
//      self.handleAppUpdateTask(task as! BGAppRefreshTask)
//    }
//    if !registeredTask {
//      // Handle failure to register task
//    }
  }
}
