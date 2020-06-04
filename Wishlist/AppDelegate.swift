import BackgroundTasks
import Combine
import ComposableArchitecture
import CoreData
import UIKit
import WishlistCore
import WishlistFoundation
import WishlistServices

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
  private(set) lazy var appRepository: AppRepository = CoreDataAppRepository(container: persistentContainer)

  private lazy var store: Store<AppDelegateState, AppDelegateAction> = {
    Store(
      initialState: AppDelegateState(
        backgroundTaskState: BackgroundTaskState(
          updateAppsTask: BackgroundTaskConfiguration(id: "org.rypac.Wishlist.refresh", frequency: 30 * 60)
        )
      ),
      reducer: appDelegateReducer,
      environment: .live(
        environment: BackgroundTaskEnvironment(
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
    registerBackgroundTasks()

    return true
  }

  // MARK: UISceneSession Lifecycle

  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    let scene: SceneIdentifier

    if let userActivity = options.userActivities.first, let identifier = SceneIdentifier(activity: userActivity) {
      scene = identifier
      connectingSceneSession.userInfo = userActivity.userInfo as? [String: Any]
    } else {
      scene = .default
    }

    return scene.configuration
  }

  // MARK: - Background Tasks

  private func registerBackgroundTasks() {
    let updateTask = viewStore.backgroundTaskState.updateAppsTask
    let registeredTask = BGTaskScheduler.shared.register(forTaskWithIdentifier: updateTask.id, using: nil) { task in
      self.handleAppUpdateTask(task as! BGAppRefreshTask)
    }
    if !registeredTask {
      viewStore.send(.backgroundTask(.failedToRegisterTask(updateTask)))
    }
  }

  private func handleAppUpdateTask(_ task: BGAppRefreshTask) {
    viewStore.send(.backgroundTask(.handleAppUpdateTask(task)))
  }
}

extension BGTask: BackgroundTask {}

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
