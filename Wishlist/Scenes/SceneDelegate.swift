import Combine
import ComposableArchitecture
import SwiftUI
import UIKit
import WishlistData
import WishlistFoundation

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  private lazy var store: Store<AppState, AppAction> = {
    let apps: [App]
    do {
      apps = try appDelegate.appRepository.fetchAll()
    } catch {
      apps = []
    }

    return Store(
      initialState: AppState(
        apps: apps,
        sortOrder: appDelegate.settings.sortOrder
      ),
      reducer: appReducer,
      environment: AppEnvironment(
        repository: appDelegate.appRepository,
        mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
        loadApps: appDelegate.appStore.lookup(ids:),
        settings: appDelegate.settings
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
    appDelegate.wishlistUpdater.performPeriodicUpdate()
    viewStore.send(.lifecycle(.didBecomeAction))
  }

  func sceneDidEnterBackground(_ scene: UIScene) {
    appDelegate.scheduleAppRefresh()
    viewStore.send(.lifecycle(.didEnterBackground))
  }

  func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
    if let urlContext = urlContexts.first {
      viewStore.send(.lifecycle(.openURL(urlContext.url)))
    }
  }

  private var appDelegate: AppDelegate {
    UIApplication.shared.delegate as! AppDelegate
  }
}

// MARK: - App State

struct AppState: Equatable {
  var apps: [App] {
    didSet {
      appListState.apps = apps
      urlSchemeState.apps = apps
    }
  }
  var appListState: AppListState
  var urlSchemeState: URLSchemeState

  init(apps: [App], sortOrder: SortOrder) {
    self.apps = apps
    self.appListState = AppListState(apps: apps, sortOrder: sortOrder)
    self.urlSchemeState = URLSchemeState(apps: apps)
  }
}

enum AppLifecycleEvent {
  case didStart
  case didBecomeAction
  case didEnterBackground
  case openURL(URL)
}

enum AppAction {
  case appsUpdated([App])
  case appList(AppListAction)
  case urlScheme(URLSchemeAction)
  case lifecycle(AppLifecycleEvent)
  case addAppsResponse(Result<[App], Error>)
  case addApps(ids: [Int])
}

struct AppEnvironment {
  let repository: AppRepository
  let mainQueue: AnySchedulerOf<DispatchQueue>
  let loadApps: ([Int]) -> AnyPublisher<[App], Error>
  let settings: SettingsStore
}

let appReducer: Reducer<AppState, AppAction, AppEnvironment> = .combine(
  Reducer { state, action, environment in
    switch action {
    case .appsUpdated(let apps):
      state.appListState.apps = apps
      state.appListState.apps.sort(by: state.appListState.sortOrder)
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
    case .addApps(let ids):
      return environment.loadApps(ids)
        .subscribe(on: environment.mainQueue)
        .catchToEffect()
        .map(AppAction.addAppsResponse)
    case .addAppsResponse(.success(let apps)):
      return .fireAndForget {
        try? environment.repository.add(apps)
      }
    case .addAppsResponse(.failure), .urlScheme, .appList, .lifecycle:
      return .none
    }
  },
  appListReducer.pullback(
    state: \.appListState,
    action: /AppAction.appList,
    environment: {
      AppListEnvironment(
        repository: $0.repository,
        settings: $0.settings,
        loadApps: pipe(AppStore.extractIDs, $0.loadApps),
        mainQueue: $0.mainQueue
      )
    }
  ),
  urlSchemeReducer.pullback(
    state: \.urlSchemeState,
    action: /AppAction.urlScheme,
    environment: { environment in
      URLSchemeEnvironment(
        loadApps: environment.loadApps,
        addApps: { apps in try? environment.repository.add(apps) },
        deleteApps: { ids in try? environment.repository.delete(ids: ids) },
        mainQueue: environment.mainQueue
      )
    }
  )
)

// MARK: - URLScheme

struct URLSchemeState: Equatable {
  var apps: [App]
  var loadingApps: Bool = false
}

enum URLSchemeAction {
  case handleURLScheme(URLScheme)
  case addAppsResponse(Result<[App], Error>)
}

struct URLSchemeEnvironment {
  let loadApps: ([App.ID]) -> AnyPublisher<[App], Error>
  let addApps: ([App]) -> Void
  let deleteApps: ([App.ID]) -> Void
  let mainQueue: AnySchedulerOf<DispatchQueue>
}

let urlSchemeReducer = Reducer<URLSchemeState, URLSchemeAction, URLSchemeEnvironment> { state, action, environment in
  switch action {
  case .addAppsResponse(let result):
    state.loadingApps = false
    switch result {
    case .success(let apps):
      return .fireAndForget {
        environment.addApps(apps)
      }
    case .failure:
      return .none
    }
  case .handleURLScheme(let urlScheme):
    switch urlScheme {
    case .addApps(let ids):
      state.loadingApps = true
      return environment.loadApps(ids)
        .subscribe(on: environment.mainQueue)
        .catchToEffect()
        .map(URLSchemeAction.addAppsResponse)
    case .export:
      let addAppsURLScheme = URLScheme.addApps(ids: state.apps.map(\.id))
      return .fireAndForget {
        print(addAppsURLScheme.rawValue)
      }
    case .deleteAll:
      let appIDs = state.apps.map(\.id)
      return .fireAndForget {
        environment.deleteApps(appIDs)
      }
    }
  }
}
