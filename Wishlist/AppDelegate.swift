import WishlistShared
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  let wishlist: Wishlist
  let settings: SettingsStore

  private let wishlistUpdater: WishlistUpdater

  override init() {
    let database = try! Database()
    let appStore = AppStoreService()
    settings = SettingsStore()
    wishlist = Wishlist(database: database, appStore: appStore)
    wishlistUpdater = WishlistUpdater(wishlist: wishlist, appStore: appStore)
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
