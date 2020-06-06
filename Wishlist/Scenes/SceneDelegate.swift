import Combine
import ComposableArchitecture
import SwiftUI
import UIKit
import WishlistCore
import WishlistFoundation

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  private lazy var store: Store<AppState, AppAction> = {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    return Store(
      initialState: AppState(
        apps: IdentifiedArrayOf((try? appDelegate.appRepository.fetchAll()) ?? []),
        sortOrderState: SortOrderState(
          sortOrder: appDelegate.settings.sortOrder,
          configuration: SortOrder.Configuration(
            price: .init(sortLowToHigh: true, includeFree: true),
            title: .init(sortAToZ: true),
            update: .init(sortByMostRecent: true)
          )
        ),
        lastUpdateDate: appDelegate.settings.lastUpdateDate,
        theme: appDelegate.settings.theme,
        appUpdateFrequency: 5 * 60
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
            self?.window?.overrideUserInterfaceStyle = UIUserInterfaceStyle(theme)
          }
        )
      )
    )
  }()
  private lazy var viewStore: ViewStore<AppState, AppAction> = ViewStore(store)

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    let window = UIWindow(windowScene: scene as! UIWindowScene)
    window.rootViewController = UIHostingController(
      rootView: AppListView(
        store: store.scope(state: \.appListState, action: AppAction.appList)
      )
    )
    self.window = window
    window.makeKeyAndVisible()
    viewStore.send(.lifecycle(.willConnect))

    if let urlContext = connectionOptions.urlContexts.first {
      viewStore.send(.lifecycle(.openURL(urlContext.url)))
    }
  }

  func sceneWillEnterForeground(_ scene: UIScene) {
    viewStore.send(.lifecycle(.willEnterForground))
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
  var apps: IdentifiedArrayOf<App>
  var sortOrderState: SortOrderState
  var lastUpdateDate: Date?
  var theme: Theme
  var appUpdateFrequency: TimeInterval
  var appListInternalState: AppListInternalState
  var viewingAppDetails: AppDetailsState? = nil
  var isSettingsPresented: Bool = false
  var isUpdateInProgress: Bool = false

  init(
    apps: IdentifiedArrayOf<App>,
    sortOrderState: SortOrderState,
    lastUpdateDate: Date?,
    theme: Theme,
    appUpdateFrequency: TimeInterval
  ) {
    self.apps = apps
    self.sortOrderState = sortOrderState
    self.lastUpdateDate = lastUpdateDate
    self.theme = theme
    self.appUpdateFrequency = appUpdateFrequency
    self.appListInternalState = AppListInternalState(sortOrder: sortOrderState.sortOrder)
  }
}

private extension AppState {
  var appListState: AppListState {
    get {
      AppListState(
        apps: apps,
        sortOrderState: sortOrderState,
        theme: theme,
        internalState: appListInternalState,
        displayedAppDetails: viewingAppDetails,
        isSettingsPresented: isSettingsPresented
      )
    }
    set {
      apps = newValue.apps
      sortOrderState = newValue.sortOrderState
      theme = newValue.theme
      appListInternalState = newValue.internalState
      isSettingsPresented = newValue.isSettingsPresented
      viewingAppDetails = newValue.displayedAppDetails
    }
  }

  var urlSchemeState: URLSchemeState {
    get {
      URLSchemeState(apps: apps.elements, viewingAppDetails: viewingAppDetails?.app.id)
    }
    set {
      apps = IdentifiedArrayOf(newValue.apps)
      if let id = newValue.viewingAppDetails, let app = apps[id: id] {
        viewingAppDetails = AppDetailsState(app: app, versions: nil, showVersionHistory: false)
      }
    }
  }

  var appUpdateState: AppUpdateState {
    get {
      AppUpdateState(
        apps: apps.elements,
        lastUpdateDate: lastUpdateDate,
        updateFrequency: appUpdateFrequency,
        isUpdateInProgress: isUpdateInProgress
      )
    }
    set {
      apps = IdentifiedArrayOf(newValue.apps)
      lastUpdateDate = newValue.lastUpdateDate
      appUpdateFrequency = newValue.updateFrequency
      isUpdateInProgress = newValue.isUpdateInProgress
    }
  }

  var processUpdateState: ProcessUpdateState {
    get {
      ProcessUpdateState(apps: apps.elements, sortOrder: sortOrderState.sortOrder, theme: theme)
    }
    set {
      apps = IdentifiedArrayOf(newValue.apps)
      sortOrderState.sortOrder = newValue.sortOrder
      theme = newValue.theme
    }
  }
}

enum AppAction {
  case appList(AppListAction)
  case urlScheme(URLSchemeAction)
  case lifecycle(SceneLifecycleEvent)
  case updates(AppUpdateAction)
  case settings(SettingsAction)
  case processUpdates(ProcessUpdateAction)
}

struct AppEnvironment {
  var repository: AppRepository
  var settings: Settings
  var loadApps: ([App.ID]) -> AnyPublisher<[AppSnapshot], Error>
  var openURL: (URL) -> Void
  var scheduleBackgroundTasks: () -> Void
  var setTheme: (Theme) -> Void
}

let appReducer = Reducer<AppState, AppAction, SystemEnvironment<AppEnvironment>>.combine(
  appListReducer.pullback(
    state: \.appListState,
    action: /AppAction.appList,
    environment: { systemEnvironment in
      systemEnvironment.map {
        AppListEnvironment(
          loadApps: $0.loadApps,
          deleteApps: { ids in
            try? systemEnvironment.repository.delete(ids: ids)
          },
          versionHistory: { id in
            (try? systemEnvironment.repository.versionHistory(id: id)) ?? []
          },
          saveNotifications: { id, notifications in
            try? systemEnvironment.repository.notify(id: id, for: notifications)
          },
          openURL: $0.openURL,
          saveSortOrder: { sortOrder in
            systemEnvironment.settings.sortOrder = sortOrder
          },
          saveTheme: { theme in
            systemEnvironment.settings.theme = theme
          },
          recordDetailsViewed: { id, date in
            try? systemEnvironment.repository.viewedApp(id: id, at: date)
          }
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
            publisher: environment.settings.$theme.publisher(initialValue: .skip).eraseToAnyPublisher(),
            perform: environment.setTheme
          )
        )
      }
    }
  ),
  Reducer { state, action, environment in
    switch action {
    case .lifecycle(.willConnect):
      return Effect(value: .processUpdates(.subscribe))

    case let .lifecycle(.openURL(url)):
      guard let urlScheme = URLScheme(rawValue: url) else {
        return .none
      }
      return Effect(value: .urlScheme(.handleURLScheme(urlScheme)))

    case .lifecycle(.didBecomeActive):
      return Effect(value: .updates(.checkForUpdates))

    case .lifecycle(.willEnterForground):
      let theme = state.theme
      return .fireAndForget {
        environment.setTheme(theme)
      }

    case .lifecycle(.didEnterBackground):
      return .fireAndForget {
        environment.scheduleBackgroundTasks()
      }

    case let .updates(.receivedUpdates(.success(updatedApps), at: date)):
      return .fireAndForget {
        try? environment.repository.add(updatedApps)
        environment.settings.lastUpdateDate = date
      }

    case let .appList(.addApps(.addAppsResponse(.success(apps)))),
         let .urlScheme(.addApps(.addAppsResponse(.success(apps)))):
      return .fireAndForget {
        try? environment.repository.add(apps)
      }

    case .lifecycle, .urlScheme, .appList, .updates, .settings, .processUpdates:
      return .none
    }
  },
  Reducer { state, action, environment in
    switch action {
    case .lifecycle(.willConnect),
         .processUpdates(.apps(.receivedValue)),
         .updates(.receivedUpdates(.success, _)),
         .urlScheme(.addApps(.addAppsResponse(.success))):
      return Effect(value: .appList(.sortOrderUpdated))

    default:
      return .none
    }
  }
)
