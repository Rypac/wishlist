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
        sortOrder: appDelegate.settings.sortOrder
      ),
      reducer: appReducer,
      environment: AppEnvironment(
        repository: appDelegate.appRepository,
        mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
        loadApps: appDelegate.appStore.lookup,
        openURL: { UIApplication.shared.open($0) },
        settings: appDelegate.settings,
        scheduleBackgroundTasks: { appDelegate.viewStore.send(.backgroundTask(.scheduleAppUpdateTask)) }
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
  var viewingAppDetails: App.ID? = nil
  var isLoadingAppsFromURLScheme: Bool = false
  var isSortOrderSheetPresented: Bool = false
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
}

enum AppLifecycleEvent {
  case didStart
  case didBecomeActive
  case didEnterBackground
  case openURL(URL)
}

enum AppAction {
  case appsUpdated([App])
  case appList(AppListAction)
  case urlScheme(URLSchemeAction)
  case lifecycle(AppLifecycleEvent)
}

struct AppEnvironment {
  let repository: AppRepository
  let mainQueue: AnySchedulerOf<DispatchQueue>
  let loadApps: ([Int]) -> AnyPublisher<[App], Error>
  let openURL: (URL) -> Void
  let settings: SettingsStore
  let scheduleBackgroundTasks: () -> Void
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  Reducer { state, action, environment in
    switch action {
    case .appsUpdated(let apps):
      state.appListState.apps = apps
      return .none
    case .lifecycle(.didStart):
      return environment.repository.publisher()
        .eraseToEffect()
        .map(AppAction.appsUpdated)
    case .lifecycle(.openURL(let url)):
      guard let urlScheme = URLScheme(rawValue: url) else {
        return .none
      }
      return Effect(value: .urlScheme(.handleURLScheme(urlScheme)))
    case .lifecycle(.didBecomeActive):
      let apps = state.apps
      return .async { _ in
        checkForUpdates(apps: apps, lookup: environment.loadApps)
          .sink(receiveCompletion: { _ in }) { newApps in
            try? environment.repository.add(newApps)
          }
      }
    case .lifecycle(.didEnterBackground):
      return .fireAndForget {
        environment.scheduleBackgroundTasks()
      }
    case .urlScheme, .appList:
      return .none
    }
  },
  appListReducer.pullback(
    state: \.appListState,
    action: /AppAction.appList,
    environment: { environment in
      AppListEnvironment(
        repository: environment.repository,
        persistSortOrder: { environment.settings.sortOrder = $0 },
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
  )
)
