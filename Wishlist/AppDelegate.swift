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

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    settings.register()
//    registerBackgroundTasks()

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

// MARK: - Background Task Reducer

struct BackgroundTask {
  let identifier: String
  let frequency: TimeInterval
}

extension BackgroundTask {
  static let updateApps = BackgroundTask(identifier: "org.rypac.Wishlist.refresh", frequency: 30 * 60)
}

enum BackgroundTaskAction {
  case registerTasks
  case scheduleTask(BackgroundTask)
  case handleAppUpdateTask(BGAppRefreshTask)
}

struct BackgroundTaskEnvironment {
  var registerTask: (BackgroundTask) -> Effect<BGTask, Never>
  var submitTask: (BGTaskRequest) throws -> Void
  var fetchApps: () -> [App]
  var checkForUpdates: ([App]) -> AnyPublisher<[App], Error>
  var saveUpdatedApps: ([App]) -> Void
  var now: () -> Date
}

let backgroundTaskReducer = Reducer<Void, BackgroundTaskAction, BackgroundTaskEnvironment> { _, action, environment in
  switch action {
  case .registerTasks:
    return registerTask(.updateApps)
      .map { .handleAppUpdateTask($0 as! BGAppRefreshTask) }
  case .scheduleTask(let task):
    return .fireAndForget {
      do {
        let request = BGAppRefreshTaskRequest(identifier: task.identifier)
        request.earliestBeginDate = environment.now().addingTimeInterval(task.frequency)
        try environment.submitTask(request)
      } catch {
        print("Could not schedule app refresh: \(error)")
      }
    }
  case .handleAppUpdateTask(let task):
    return .concatenate(
      Effect(value: .scheduleTask(.updateApps)),
      .async { _ in
        let apps = environment.fetchApps()
        let cancellable = environment.checkForUpdates(apps)
          .sink(receiveCompletion: { _ in }) { newApps in
            environment.saveUpdatedApps(newApps)
          }
        task.expirationHandler = {
          cancellable.cancel()
        }
        return cancellable
      }
    )
  }
}

private struct FailedToRegisterTaskError: Error {}

func registerTask(_ task: BackgroundTask, queue: DispatchQueue? = nil) -> Effect<BGTask, Never> {
  .future { thing in
    BGTaskScheduler.shared.register(forTaskWithIdentifier: task.identifier, using: queue) { task in
      thing(.success(task))
    }
  }
}
