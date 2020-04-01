import CoreData
import UIKit
import WishlistServices
import WishlistShared

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  let settings = SettingsStore()

  lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentCloudKitContainer(name: "DataModel")
    let storeURL = FileManager.default.storeURL(for: "group.wishlist.database", databaseName: "Wishlist")
    let storeDescription = NSPersistentStoreDescription(url: storeURL)
    container.persistentStoreDescriptions = [storeDescription]
    container.loadPersistentStores() { des, error in
      if let error = error as NSError? {
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    }
    return container
  }()

  private lazy var database = CoreDataDatabase(context: persistentContainer.viewContext)

  private let appStore = AppStoreService()
  private(set) lazy var wishlist = Wishlist(database: database, appLookupService: appStore)
  private(set) lazy var wishlistUpdater = WishlistUpdater(wishlist: wishlist, appLookupService: appStore)

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    settings.register()

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

public extension FileManager {
  func storeURL(for appGroup: String, databaseName: String) -> URL {
    guard let fileContainer = containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
      fatalError("Shared file container could not be created.")
    }
    return fileContainer.appendingPathComponent("\(databaseName).sqlite")
  }
}
