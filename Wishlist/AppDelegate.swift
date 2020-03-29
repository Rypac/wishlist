import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  let wishlist = Wishlist(database: try! Database())
  let settings = SettingsStore()

  private let wishlistUpdater: WishlistUpdater

  override init() {
    wishlistUpdater = WishlistUpdater(wishlist: wishlist, appStore: AppStoreService())
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
