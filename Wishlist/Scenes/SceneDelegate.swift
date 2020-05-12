import Combine
import ComposableArchitecture
import SwiftUI
import UIKit
import WishlistData

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  private lazy var store: Store<AppState, AppAction> = {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    return Store(
      initialState: AppState(
        apps: (try? appDelegate.appRepository.fetchAll()) ?? [],
        sortOrder: appDelegate.settings.sortOrder,
        lastUpdateDate: appDelegate.settings.lastUpdateDate,
        theme: appDelegate.settings.theme,
        appUpdateFrequency: 15 * 60
      ),
      reducer: appReducer,
      environment: .live(
        environment: AppEnvironment(
          repository: appDelegate.appRepository,
          settings: appDelegate.settings,
          loadApps: appDelegate.appStore.lookup,
          openURL: { UIApplication.shared.open($0) },
          scheduleBackgroundTasks: {
            appDelegate.viewStore.send(.backgroundTask(.scheduleAppUpdateTask))
          },
          setTheme: { [weak self] theme in
            appDelegate.settings.theme = theme
            self?.window?.overrideUserInterfaceStyle = UIUserInterfaceStyle(theme)
          }
        )
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
  var theme: Theme
  var appUpdateFrequency: TimeInterval
  var viewingAppDetails: App.ID? = nil
  var isSettingsSheetPresented: Bool = false
  var isSortOrderSheetPresented: Bool = false
  var isUpdateInProgress: Bool = false
}

private extension AppState {
  var appListState: AppListState {
    get {
      AppListState(
        apps: apps,
        sortOrder: sortOrder,
        theme: theme,
        displayedAppDetailsID: viewingAppDetails,
        isSettingsSheetPresented: isSettingsSheetPresented,
        isSortOrderSheetPresented: isSortOrderSheetPresented
      )
    }
    set {
      apps = newValue.apps
      sortOrder = newValue.sortOrder
      theme = newValue.theme
      isSettingsSheetPresented = newValue.isSettingsSheetPresented
      isSortOrderSheetPresented = newValue.isSortOrderSheetPresented
      viewingAppDetails = newValue.displayedAppDetailsID
    }
  }

  var urlSchemeState: URLSchemeState {
    get {
      URLSchemeState(
        apps: apps,
        viewingAppDetails: viewingAppDetails
      )
    }
    set {
      apps = newValue.apps
      viewingAppDetails = newValue.viewingAppDetails
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

  var settingsState: SettingsState {
    get {
      SettingsState(theme: theme)
    }
    set {
      theme = newValue.theme
    }
  }

  var processUpdateState: ProcessUpdateState {
    get {
      ProcessUpdateState(apps: apps, sortOrder: sortOrder, theme: theme)
    }
    set {
      apps = newValue.apps
      sortOrder = newValue.sortOrder
      theme = newValue.theme
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
  case appList(AppListAction)
  case urlScheme(URLSchemeAction)
  case lifecycle(AppLifecycleEvent)
  case updates(AppUpdateAction)
  case settings(SettingsAction)
  case processUpdates(ProcessUpdateAction)
}

struct AppEnvironment {
  var repository: AppRepository
  var settings: Settings
  var loadApps: ([App.ID]) -> AnyPublisher<[App], Error>
  var openURL: (URL) -> Void
  var scheduleBackgroundTasks: () -> Void
  var setTheme: (Theme) -> Void
}

let appReducer = Reducer<AppState, AppAction, SystemEnvironment<AppEnvironment>>.combine(
  Reducer { state, action, environment in
    switch action {
    case .lifecycle(.didStart):
      return Effect(value: .processUpdates(.subscribe))
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
    case let .appList(.addApps(.addAppsResponse(.success(apps)))),
         let .urlScheme(.addApps(.addAppsResponse(.success(apps)))):
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
    case .urlScheme, .appList, .updates, .settings, .processUpdates:
      return .none
    }
  },
  appListReducer.pullback(
    state: \.appListState,
    action: /AppAction.appList,
    environment: { systemEnvironment in
      systemEnvironment.map {
        AppListEnvironment(
          loadApps: $0.loadApps,
          openURL: $0.openURL,
          saveTheme: $0.setTheme
        )
      }
    }
  ),
  urlSchemeReducer.pullback(
    state: \.urlSchemeState,
    action: /AppAction.urlScheme,
    environment: { systemEnvironment in
      systemEnvironment.map {
        URLSchemeEnvironment(loadApps: $0.loadApps)
      }
    }
  ),
  appUpdateReducer.pullback(
    state: \.appUpdateState,
    action: /AppAction.updates,
    environment: { systemEnvironment in
      systemEnvironment.map {
        AppUpdateEnvironment(lookupApps: $0.loadApps)
      }
    }
  ),
  settingsReducer.pullback(
    state: \.settingsState,
    action: /AppAction.settings,
    environment: { systemEnvironment in
      SettingsEnvironment(saveTheme: systemEnvironment.setTheme)
    }
  ),
  processUpdateReducer.pullback(
    state: \.processUpdateState,
    action: /AppAction.processUpdates,
    environment: { systemEnvironment in
      systemEnvironment.map { environment in
        ProcessUpdateEnvironment(
          apps: PublisherEnvironment(
            publisher: environment.repository.publisher()
          ),
          sortOrder: PublisherEnvironment(
            publisher: environment.settings.$sortOrder.publisher(initialValue: .skip).eraseToAnyPublisher()
          ),
          theme: PublisherEnvironment(
            publisher: environment.settings.$theme.publisher().eraseToAnyPublisher(),
            perform: environment.setTheme
          )
        )
      }
    }
  )
)
