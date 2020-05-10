import Combine
import ComposableArchitecture
import SwiftUI
import UIKit
import WishlistData
import WishlistFoundation

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  private lazy var store: Store<AppState, AppAction> = {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    return Store(
      initialState: AppState(
        apps: (try? appDelegate.appRepository.fetchAll()) ?? [],
        sortOrder: appDelegate.settings.sortOrder,
        lastUpdateDate: appDelegate.settings.lastUpdateDate,
        appUpdateFrequency: 15 * 60
      ),
      reducer: appReducer,
      environment: AppEnvironment(
        repository: appDelegate.appRepository,
        mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
        loadApps: appDelegate.appStore.lookup,
        openURL: { UIApplication.shared.open($0) },
        settings: appDelegate.settings,
        scheduleBackgroundTasks: { appDelegate.viewStore.send(.backgroundTask(.scheduleAppUpdateTask)) },
        now: Date.init
      )
    )
  }()
  private lazy var viewStore: ViewStore<AppState, AppAction> = ViewStore(store)

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    if let windowScene = scene as? UIWindowScene {
      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = UIHostingController(
        rootView: AppListView(
          store: store.scope(state: \.appListState, action: AppAction.appList)
        )
      )
      self.window = window
      window.makeKeyAndVisible()
      viewStore.send(.lifecycle(.didStart))
    }

    if let urlContext = connectionOptions.urlContexts.first {
      viewStore.send(.lifecycle(.openURL(urlContext.url)))
    }
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    viewStore.send(.lifecycle(.didBecomeActive))
  }

  func sceneDidEnterBackground(_ scene: UIScene) {
    viewStore.send(.lifecycle(.didEnterBackground))
  }

  func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
    if let urlContext = urlContexts.first {
      viewStore.send(.lifecycle(.openURL(urlContext.url)))
    }
  }
}

// MARK: - App State

struct AppState: Equatable {
  var apps: [App]
  var sortOrder: SortOrder
  var lastUpdateDate: Date?
  var appUpdateFrequency: TimeInterval
  var viewingAppDetails: App.ID? = nil
  var isLoadingAppsFromURLScheme: Bool = false
  var isSortOrderSheetPresented: Bool = false
  var isUpdateInProgress: Bool = false
}

extension AppState {
  var appListState: AppListState {
    get {
      AppListState(
        apps: apps,
        sortOrder: sortOrder,
        displayedAppDetailsID: viewingAppDetails,
        isSortOrderSheetPresented: isSortOrderSheetPresented
      )
    }
    set {
      apps = newValue.apps
      sortOrder = newValue.sortOrder
      isSortOrderSheetPresented = newValue.isSortOrderSheetPresented
      viewingAppDetails = newValue.displayedAppDetailsID
    }
  }

  var urlSchemeState: URLSchemeState {
    get {
      URLSchemeState(
        apps: apps,
        viewingAppDetails: viewingAppDetails,
        loadingApps: isLoadingAppsFromURLScheme
      )
    }
    set {
      apps = newValue.apps
      viewingAppDetails = newValue.viewingAppDetails
      isLoadingAppsFromURLScheme = newValue.loadingApps
    }
  }

  var appUpdateState: AppUpdateState {
    get {
      AppUpdateState(
        apps: apps,
        lastUpdateDate: lastUpdateDate,
        updateFrequency: appUpdateFrequency,
        isUpdateInProgress: isUpdateInProgress
      )
    }
    set {
      apps = newValue.apps
      lastUpdateDate = newValue.lastUpdateDate
      appUpdateFrequency = newValue.updateFrequency
      isUpdateInProgress = newValue.isUpdateInProgress
    }
  }
}

enum AppLifecycleEvent {
  case didStart
  case didBecomeActive
  case didEnterBackground
  case openURL(URL)
}

enum AppAction {
  case appsUpdated([App])
  case sortOrderUpdated(SortOrder)
  case appList(AppListAction)
  case urlScheme(URLSchemeAction)
  case lifecycle(AppLifecycleEvent)
  case updates(AppUpdateAction)
}

struct AppEnvironment {
  let repository: AppRepository
  let mainQueue: AnySchedulerOf<DispatchQueue>
  let loadApps: ([Int]) -> AnyPublisher<[App], Error>
  let openURL: (URL) -> Void
  let settings: SettingsStore
  let scheduleBackgroundTasks: () -> Void
  let now: () -> Date
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  Reducer { state, action, environment in
    switch action {
    case .appsUpdated(let apps):
      state.apps = apps
      return .none
    case let .sortOrderUpdated(sortOrder):
      state.sortOrder = sortOrder
      return .fireAndForget {
        environment.settings.sortOrder = sortOrder
      }
    case .lifecycle(.didStart):
      return .merge(
        environment.repository.publisher()
          .receive(on: environment.mainQueue)
          .eraseToEffect()
          .map(AppAction.appsUpdated),
        environment.settings.$sortOrder.publisher()
          .removeDuplicates()
          .receive(on: environment.mainQueue)
          .eraseToEffect()
          .map(AppAction.sortOrderUpdated)
      )
    case let .lifecycle(.openURL(url)):
      guard let urlScheme = URLScheme(rawValue: url) else {
        return .none
      }
      return Effect(value: .urlScheme(.handleURLScheme(urlScheme)))
    case .lifecycle(.didBecomeActive):
      return Effect(value: .updates(.checkForUpdates))
    case .lifecycle(.didEnterBackground):
      return .fireAndForget {
        environment.scheduleBackgroundTasks()
      }
    case let .updates(.receivedUpdates(updatedApps, at: date)):
      return .fireAndForget {
        try? environment.repository.add(updatedApps)
        environment.settings.lastUpdateDate = date
      }
    case let .appList(.addAppsResponse(.success(apps))), let .urlScheme(.addAppsResponse(.success(apps))):
      return .fireAndForget {
        try? environment.repository.add(apps)
      }
    case let .appList(.removeApps(ids)):
      return .fireAndForget {
        try? environment.repository.delete(ids: ids)
      }
    case let .appList(.setSortOrder(sortOrder)):
      return .fireAndForget {
        environment.settings.sortOrder = sortOrder
      }
    case .urlScheme, .appList, .updates:
      return .none
    }
  },
  appListReducer.pullback(
    state: \.appListState,
    action: /AppAction.appList,
    environment: { environment in
      AppListEnvironment(
        loadApps: pipe(AppStore.extractIDs, environment.loadApps),
        openURL: environment.openURL,
        mainQueue: environment.mainQueue
      )
    }
  ),
  urlSchemeReducer.pullback(
    state: \.urlSchemeState,
    action: /AppAction.urlScheme,
    environment: { environment in
      URLSchemeEnvironment(
        loadApps: environment.loadApps,
        mainQueue: environment.mainQueue
      )
    }
  ),
  appUpdateReducer.pullback(
    state: \.appUpdateState,
    action: /AppAction.updates,
    environment: { environment in
      AppUpdateEnvironment(
        lookupApps: environment.loadApps,
        mainQueue: environment.mainQueue,
        now: environment.now
      )
    }
  )
)
