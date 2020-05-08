import BackgroundTasks
import Combine
import ComposableArchitecture
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

  private lazy var store: Store<AppDelegateState, AppDelegateAction> = {
    Store(
      initialState: AppDelegateState(
        backgroundTaskState: BackgroundTaskState(
          updateAppsTask: BackgroundTask(id: "org.rypac.Wishlist.refresh", frequency: 30 * 60)
        )
      ),
      reducer: appDelegateReducer,
      environment: AppDelegateEnvironment(
        registerTask: BGTaskScheduler.shared.register,
        submitTask: BGTaskScheduler.shared.submit,
        fetchApps: { (try? self.appRepository.fetchAll()) ?? [] },
        checkForUpdates: { apps in checkForUpdates(apps: apps, lookup: self.appStore.lookup) },
        saveUpdatedApps: { try? self.appRepository.add($0) },
        now: Date.init
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

    return activity.sceneConfiguration()
  }
}

// MARK: - Composable Architecture

struct AppDelegateState: Equatable {
  var backgroundTaskState: BackgroundTaskState
}

enum AppDelegateAction {
  case backgroundTask(BackgroundTaskAction)
}

typealias AppDelegateEnvironment = BackgroundTaskEnvironment

let appDelegateReducer = backgroundTaskReducer.pullback(
  state: \AppDelegateState.backgroundTaskState,
  action: /AppDelegateAction.backgroundTask,
  environment: { (environment: AppDelegateEnvironment) in environment }
)

// MARK: - Background Tasks

extension BGTaskScheduler {
  func register(task: BackgroundTask) -> Effect<BGTask, Never> {
    .async { subscriber in
      BGTaskScheduler.shared.register(forTaskWithIdentifier: task.id, using: nil) { task in
        subscriber.send(task)
      }
      return AnyCancellable {}
    }
  }
}
