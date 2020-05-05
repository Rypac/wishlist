import BackgroundTasks
import CoreData
import UIKit
import WishlistServices
import WishlistData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  let settings = SettingsStore()

  private(set) lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentCloudKitContainer(name: "DataModel")

    let storeURL = FileManager.default.storeURL(for: "group.wishlist.database", databaseName: "Wishlist")
    let cloudStoreDescription = NSPersistentStoreDescription(url: storeURL)
    cloudStoreDescription.configuration = "Cloud"
    cloudStoreDescription.cloudKitContainerOptions =
      NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.org.rypac.Wishlist")
    container.persistentStoreDescriptions = [cloudStoreDescription]

    container.loadPersistentStores() { _, error in
      if let error = error as NSError? {
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    }
    return container
  }()

  let appStore: AppLookupService = AppStoreService()
  private(set) lazy var appRepository: AppRepository = CoreDataAppRepository(context: persistentContainer.viewContext)
  private(set) lazy var wishlistUpdater = UpdateWishlistService(appRepository: appRepository, appLookupService: appStore, updateScheduler: WishlistUpdateScheduler())
  private(set) lazy var wishlistAdder = AddToWishlistService(appRepository: appRepository, appLookupService: appStore)

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    settings.register()
    registerBackgroundTasks()

    return true
  }

  // MARK: UISceneSession Lifecycle

  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    let activity: ActivityIdentifier

    if let userActivity = options.userActivities.first, let specifiedActivity = ActivityIdentifier(rawValue: userActivity.activityType) {
      activity = specifiedActivity
      connectingSceneSession.userInfo = userActivity.userInfo as? [String: Any]
    } else {
      activity = .list
    }

    return activity.sceneConfiguration()
  }
}

// MARK: - Background Tasks

extension AppDelegate {
  private static let refreshTaskIdentifier = "org.rypac.Wishlist.refresh"

  func registerBackgroundTasks() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskIdentifier, using: nil) { task in
      self.handleAppRefresh(task: task as! BGAppRefreshTask)
    }
  }

  func scheduleAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)

    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      print("Could not schedule app refresh: \(error)")
    }
  }

  func handleAppRefresh(task: BGAppRefreshTask) {
    scheduleAppRefresh()
    wishlistUpdater.performBackgroundUpdate(task: task)
  }
}
