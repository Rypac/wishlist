import BackgroundTasks
import Domain
import Foundation
import Services
import SQLite
import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
  let settings = Settings()
  let system: SystemEnvironment = .live
  let appAdder: AppAdder
  let updateChecker: UpdateChecker
  let urlSchemeHandler: URLSchemeHandler
  let appRepository: AppRepository

  private let backgroundAppRefresh: BackgroundAppRefresh
  private let backgroundDatabaseMaintenance: BackgroundDatabaseMaintenance

  override init() {
    let databaseWriter: DatabaseWriter = try! DatabaseQueue(
      location: DatabaseLocation(
        url: FileManager.default.storeURL(for: "group.watchlist.database", databaseName: "Wishlist")
      )
    )
    appRepository = AppRepository(
      persistence: try! SQLiteAppPersistence(databaseWriter: databaseWriter)
    )

    let appStore: AppLookupService = AppStoreService()
    appAdder = AppAdder(
      environment: AppAdder.Environment(
        loadApps: appStore.lookup,
        saveApps: appRepository.saveApps,
        now: system.now
      )
    )
    updateChecker = UpdateChecker(
      environment: UpdateChecker.Environment(
        fetchApps: appRepository.fetchApps,
        lookupApps: appStore.lookup,
        saveApps: appRepository.saveApps,
        system: system,
        lastUpdateDate: settings.$lastUpdateDate,
        updateFrequency: 5 * 60
      )
    )
    backgroundAppRefresh = BackgroundAppRefresh(
      id: "org.rypac.Watchlist.refresh",
      frequency: 30 * 60,
      updateChecker: updateChecker,
      now: system.now
    )
    backgroundDatabaseMaintenance = BackgroundDatabaseMaintenance(
      id: "org.rypac.Watchlist.database-maintenance",
      cleanupDatabase: {
        try await databaseWriter.writeAsync { database in
          try database.vacuum()
        }
      },
      now: system.now
    )
    urlSchemeHandler = URLSchemeHandler(
      environment: URLSchemeHandler.Environment(
        fetchApps: appRepository.fetchApps,
        addApps: appAdder.addApps,
        deleteAllApps: appRepository.deleteAllApps
      )
    )
  }

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    settings.register()
    registerBackgroundTasks()

    return true
  }

  // MARK: - Background Tasks

  private func registerBackgroundTasks() {
    BGTaskScheduler.shared.register(backgroundAppRefresh)
    BGTaskScheduler.shared.register(backgroundDatabaseMaintenance)
  }

  func scheduleBackgroundTasks() {
    BGTaskScheduler.shared.schedule(backgroundAppRefresh)
    BGTaskScheduler.shared.schedule(backgroundDatabaseMaintenance)
  }
}

private extension BGTaskScheduler {
  func register(_ backgroundTaskScheduler: BackgroundTaskScheduler) {
    let id = backgroundTaskScheduler.id
    let registeredTask = BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: nil) { task in
      backgroundTaskScheduler.run(task)
    }
    if !registeredTask {
      print("Failed to register task: \(id)")
    }
  }

  func schedule(_ backgroundTaskScheduler: BackgroundTaskScheduler) {
    do {
      try BGTaskScheduler.shared.submit(backgroundTaskScheduler.taskRequest)
    } catch {
      print("Failed to register task \(backgroundTaskScheduler.id): \(error)")
    }
  }
}
