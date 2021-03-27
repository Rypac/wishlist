import Combine
import ComposableArchitecture
import SwiftUI
import UIKit
import Domain

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  private lazy var store: Store<AppState, AppAction> = {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    return Store(
      initialState: AppState(
        apps: [],
        sortOrderState: SortOrderState(
          sortOrder: appDelegate.settings.sortOrder,
          configuration: SortOrder.Configuration(
            price: .init(sortLowToHigh: true, includeFree: true),
            title: .init(sortAToZ: true),
            update: .init(sortByMostRecent: true)
          )
        ),
        lastUpdateDate: appDelegate.settings.lastUpdateDate,
        settings: SettingsState(
          theme: appDelegate.settings.theme,
          notifications: NotificationState(
            enabled: appDelegate.settings.enableNotificaitons,
            notifyOnChange: appDelegate.settings.notifications
          )
        ),
        appUpdateFrequency: 5 * 60
      ),
      reducer: appReducer(id: UUID()).debugActions(),
      environment: .live(
        environment: AppEnvironment(
          repository: appDelegate.appRepository.environment,
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
    viewStore.send(.lifecycle(.willEnterForeground))
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    viewStore.send(.lifecycle(.didBecomeActive))
  }

  func sceneWillResignActive(_ scene: UIScene) {
    viewStore.send(.lifecycle(.willResignActive))
  }

  func sceneDidEnterBackground(_ scene: UIScene) {
    viewStore.send(.lifecycle(.didEnterBackground))
  }

  func sceneDidDisconnect(_ scene: UIScene) {
    viewStore.send(.lifecycle(.didDisconnect))
  }

  func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
    if let urlContext = urlContexts.first {
      viewStore.send(.lifecycle(.openURL(urlContext.url)))
    }
  }
}

// MARK: - App State

struct AppState: Equatable {
  var apps: IdentifiedArrayOf<AppDetails>
  var sortOrderState: SortOrderState
  var lastUpdateDate: Date?
  var settings: SettingsState
  var appUpdateFrequency: TimeInterval
  var viewingAppDetails: AppDetailsContent? = nil
  var isSettingsPresented: Bool = false
  var isUpdateInProgress: Bool = false
  var isAddingApps: Bool = false
}

private extension AppState {
  var appListState: AppListState {
    get {
      AppListState(
        apps: apps,
        addAppsState: addAppsState,
        sortOrderState: sortOrderState,
        settings: settings,
        displayedAppDetails: viewingAppDetails,
        isSettingsPresented: isSettingsPresented
      )
    }
    set {
      apps = newValue.apps
      addAppsState = newValue.addAppsState
      sortOrderState = newValue.sortOrderState
      settings = newValue.settings
      isSettingsPresented = newValue.isSettingsPresented
      viewingAppDetails = newValue.displayedAppDetails
    }
  }

  var addAppsState: AddAppsState {
    get {
      AddAppsState(
        apps: apps,
        addingApps: isAddingApps
      )
    }
    set {
      apps = newValue.apps
      isAddingApps = newValue.addingApps
    }
  }

  var urlSchemeState: URLSchemeState {
    get {
      URLSchemeState(
        addAppsState: addAppsState,
        viewingAppDetails: viewingAppDetails?.id
      )
    }
    set {
      addAppsState = newValue.addAppsState
      if let id = newValue.viewingAppDetails {
        viewingAppDetails = AppDetailsContent(id: id, versions: nil, showVersionHistory: false)
      }
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

  var processUpdateState: ProcessUpdateState {
    get {
      ProcessUpdateState(
        apps: apps,
        sortOrder: sortOrderState.sortOrder,
        theme: settings.theme
      )
    }
    set {
      apps = newValue.apps
      sortOrderState.sortOrder = newValue.sortOrder
      settings.theme = newValue.theme
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
  var repository: AppRepositoryEnvironment
  var settings: Settings
  var loadApps: ([AppID]) -> AnyPublisher<[AppSummary], Error>
  var openURL: (URL) -> Void
  var scheduleBackgroundTasks: () -> Void
  var setTheme: (Theme) -> Void
}

struct AppRepositoryEnvironment {
  var fetchApps: () throws -> [AppDetails]
  var saveApps: ([AppDetails]) throws -> Void
  var deleteApps: ([AppID]) throws -> Void
  var deleteAllApps: () throws -> Void
  var versionHistory: (AppID) throws -> [Version]
  var saveNotifications: (AppID, Set<ChangeNotification>) throws -> Void
  var viewedApp: (AppID, Date) throws -> Void
}

extension AppRepository {
  var environment: AppRepositoryEnvironment {
    AppRepositoryEnvironment(
      fetchApps: fetchAll,
      saveApps: add,
      deleteApps: delete,
      deleteAllApps: deleteAll,
      versionHistory: versionHistory,
      saveNotifications: notify,
      viewedApp: viewedApp
    )
  }
}

func appReducer(
  id: AnyHashable
) -> Reducer<AppState, AppAction, SystemEnvironment<AppEnvironment>> {
  .combine(
    appListReducer.pullback(
      state: \.appListState,
      action: /AppAction.appList,
      environment: { systemEnvironment in
        systemEnvironment.map {
          AppListEnvironment(
            loadApps: $0.loadApps,
            saveApps: $0.repository.saveApps,
            deleteApps: $0.repository.deleteApps,
            versionHistory: $0.repository.versionHistory,
            saveNotifications: $0.repository.saveNotifications,
            openURL: $0.openURL,
            saveSortOrder: { sortOrder in
              systemEnvironment.settings.sortOrder = sortOrder
            },
            saveTheme: { theme in
              systemEnvironment.settings.theme = theme
            },
            recordDetailsViewed: $0.repository.viewedApp
          )
        }
      }
    ),
    urlSchemeReducer.pullback(
      state: \.urlSchemeState,
      action: /AppAction.urlScheme,
      environment: { systemEnvironment in
        systemEnvironment.map { environment in
          URLSchemeEnvironment(
            loadApps: environment.loadApps,
            fetchApps: { try environment.repository.fetchApps().map(\.summary) },
            saveApps: environment.repository.saveApps,
            deleteAllApps: environment.repository.deleteAllApps
          )
        }
      }
    ),
    appUpdateReducer.pullback(
      state: \.appUpdateState,
      action: /AppAction.updates,
      environment: { systemEnvironment in
        systemEnvironment.map {
          AppUpdateEnvironment(
            lookupApps: $0.loadApps,
            saveApps: $0.repository.saveApps
          )
        }
      }
    ),
    processUpdateReducer(id: id).pullback(
      state: \.processUpdateState,
      action: /AppAction.processUpdates,
      environment: { systemEnvironment in
        systemEnvironment.map { environment in
          ProcessUpdateEnvironment(
            apps: PublisherEnvironment(
              publisher: Deferred {
                Optional.Publisher(try? environment.repository.fetchApps())
              }
              .eraseToAnyPublisher()
            ),
            sortOrder: PublisherEnvironment(
              publisher: environment.settings.$sortOrder.publisher().eraseToAnyPublisher()
            ),
            theme: PublisherEnvironment(
              publisher: environment.settings.$theme.publisher().eraseToAnyPublisher(),
              perform: environment.setTheme
            )
          )
        }
      }
    ),
    Reducer { state, action, environment in
      switch action {
      case let .lifecycle(.openURL(url)):
        guard let urlScheme = URLScheme(rawValue: url) else {
          return .none
        }
        return Effect(value: .urlScheme(.handleURLScheme(urlScheme)))

      case .lifecycle(.willEnterForeground):
        return .merge(
          Effect(value: .processUpdates(.subscribe)),
          Effect(value: .updates(.checkForUpdates))
        )

      case .lifecycle(.didEnterBackground):
        return .merge(
          Effect(value: .processUpdates(.unsubscribe)),
          Effect(value: .updates(.cancelUpdateCheck)),
          .fireAndForget {
            environment.scheduleBackgroundTasks()
          }
        )

      default:
        return .none
      }
    }
  )
}
