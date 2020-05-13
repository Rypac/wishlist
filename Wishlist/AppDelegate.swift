import BackgroundTasks
import Combine
import ComposableArchitecture
import CoreData
import UIKit
import WishlistCore
import WishlistServices
import WishlistModel

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

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

  let settings = Settings()
  let appStore: AppLookupService = AppStoreService()
  private(set) lazy var appRepository: AppRepository = CoreDataAppRepository(context: persistentContainer.viewContext)

  private lazy var store: Store<AppDelegateState, AppDelegateAction> = {
    Store(
      initialState: AppDelegateState(
        backgroundTaskState: BackgroundTaskState(
          updateAppsTask: BackgroundTask(id: "org.rypac.Wishlist.refresh", frequency: 30 * 60)
        )
      ),
      reducer: appDelegateReducer,
      environment: .live(
        environment: BackgroundTaskEnvironment(
          registerTask: BGTaskScheduler.shared.register,
          submitTask: BGTaskScheduler.shared.submit,
          fetchApps: { (try? self.appRepository.fetchAll()) ?? [] },
          lookupApps: self.appStore.lookup,
          saveUpdatedApps: { try? self.appRepository.add($0) }
        )
      )
    )
  }()
  private(set) lazy var viewStore = ViewStore(store)

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    settings.register()
    viewStore.send(.backgroundTask(.registerTasks))

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

    return activity.sceneConfiguration
  }
}

// MARK: - Composable Architecture

struct AppDelegateState: Equatable {
  var backgroundTaskState: BackgroundTaskState
}

enum AppDelegateAction {
  case backgroundTask(BackgroundTaskAction)
}

typealias AppDelegateEnvironment = SystemEnvironment<BackgroundTaskEnvironment>

let appDelegateReducer = backgroundTaskReducer.pullback(
  state: \AppDelegateState.backgroundTaskState,
  action: /AppDelegateAction.backgroundTask,
  environment: { (environment: AppDelegateEnvironment) in environment }
)
