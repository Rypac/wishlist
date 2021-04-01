import Domain
import Services
import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
  let settings = Settings()
  let appStore: AppLookupService = AppStoreService()
  private(set) lazy var appRepository: AppRepository = {
    let path = FileManager.default.storeURL(for: "group.wishlist.database", databaseName: "Wishlist")
    return try! SQLiteAppRepository(sqlite: SQLite(path: path.absoluteString))
  }()

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
