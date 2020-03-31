import CoreData
import UIKit
import WishlistServices
import WishlistShared

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  let wishlist: Wishlist
  let settings: SettingsStore

  private let wishlistUpdater: WishlistUpdater

  private lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentCloudKitContainer(name: "Wishlist")
    container.loadPersistentStores() { _, error in
      if let error = error as NSError? {
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    }
    return container
  }()

  override init() {
    let database = try! FileDatabase()
    let appStore = AppStoreService()
    settings = SettingsStore()
    wishlist = Wishlist(database: database, appLookupService: appStore)
    wishlistUpdater = WishlistUpdater(wishlist: wishlist, appLookupService: appStore)
  }

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    settings.register()
    wishlistUpdater.performUpdate()

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
