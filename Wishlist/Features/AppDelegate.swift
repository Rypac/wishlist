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
  let backgroundAppUpdater: BackgroundAppUpdater
  let urlSchemeHandler: URLSchemeHandler
  let appRepository: AppRepository = {
    let path = FileManager.default.storeURL(for: "group.watchlist.database", databaseName: "Wishlist")
    let database = try! SQLiteDatabase(location: DatabaseLocation(url: path))
    let persistence = try! SQLiteAppPersistence(sqlite: database)
    return AppRepository(persistence: persistence)
  }()

  override init() {
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
    backgroundAppUpdater = BackgroundAppUpdater(
      configuration: BackgroundTaskConfiguration(id: "org.rypac.Watchlist.refresh", frequency: 30 * 60),
      environment: BackgroundTaskEnvironment(
        submitTask: BGTaskScheduler.shared.submit,
        fetchApps: appRepository.fetchApps,
        lookupApps: appStore.lookup(ids:),
        saveUpdatedApps: appRepository.saveApps,
        system: system
      )
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
    let id = backgroundAppUpdater.configuration.id
    let registeredTask = BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: nil) { [weak self] task in
      self?.backgroundAppUpdater.run(task: task)
    }
    if !registeredTask {
      print("Failed to register task: \(id)")
    }
  }
}

extension BGTask: BackgroundTask {}
