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
        settings: SettingsState(
          theme: appDelegate.settings.theme,
          notifications: NotificationState(
            enabled: appDelegate.settings.enableNotificaitons,
            notifyOnChange: appDelegate.settings.notifications
          )
        ),
        appUpdateFrequency: 5 * 60
      ),
      reducer: appReducer(id: UUID()),
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
  var addAppsState: AddAppsState
  var sortOrderState: SortOrderState
  var lastUpdateDate: Date?
  var settings: SettingsState
  var appUpdateFrequency: TimeInterval
  var appListInternalState: AppListInternalState
  var viewingAppDetails: AppDetailsContent? = nil
  var isSettingsPresented: Bool = false
  var isUpdateInProgress: Bool = false

  init(
    apps: IdentifiedArrayOf<AppDetails>,
    sortOrderState: SortOrderState,
    lastUpdateDate: Date?,
    settings: SettingsState,
    appUpdateFrequency: TimeInterval
  ) {
    self.apps = apps
    self.addAppsState = AddAppsState(addingApps: false)
    self.sortOrderState = sortOrderState
    self.lastUpdateDate = lastUpdateDate
    self.settings = settings
    self.appUpdateFrequency = appUpdateFrequency
    self.appListInternalState = AppListInternalState(sortOrder: sortOrderState.sortOrder)
  }
}

private extension AppState {
  var appListState: AppListState {
    get {
      AppListState(
        apps: apps,
        addAppsState: addAppsState,
        sortOrderState: sortOrderState,
        settings: settings,
        internalState: appListInternalState,
        displayedAppDetails: viewingAppDetails,
        isSettingsPresented: isSettingsPresented
      )
    }
    set {
      apps = newValue.apps
      addAppsState = newValue.addAppsState
      sortOrderState = newValue.sortOrderState
      settings = newValue.settings
      appListInternalState = newValue.internalState
      isSettingsPresented = newValue.isSettingsPresented
      viewingAppDetails = newValue.displayedAppDetails
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
        lastUpdateDate: lastUpdateDate,
        updateFrequency: appUpdateFrequency,
        isUpdateInProgress: isUpdateInProgress
      )
    }
    set {
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
  var fetchApps: () -> [AppSummary]
  var saveApps: ([AppSummary]) -> Void
  var deleteApps: ([AppID]) -> Void
  var deleteAllApps: () -> Void
  var versionHistory: (AppID) -> [Version]
  var saveNotifications: (AppID, Set<ChangeNotification>) -> Void
  var viewedApp: (AppID, Date) -> Void
  var publisher: () -> AnyPublisher<[AppDetails], Never>
  var updates: () -> AnyPublisher<[AppDetails], Never>
}

extension AppRepository {
  var environment: AppRepositoryEnvironment {
    AppRepositoryEnvironment(
      fetchApps: {
        (try? fetchAll().map(\.summary)) ?? []
      },
      saveApps: { apps in
        try? add(apps)
      },
      deleteApps: { ids in
        try? delete(ids: ids)
      },
      deleteAllApps: {
        try? deleteAll()
      },
      versionHistory: { id in
        (try? versionHistory(id: id)) ?? []
      },
      saveNotifications: { id, notifications in
        try? notify(id: id, for: notifications)
      },
      viewedApp: { id, date in
        try? viewedApp(id: id, at: date)
      },
      publisher: publisher,
      updates: updates
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
        systemEnvironment.map {
          URLSchemeEnvironment(
            loadApps: $0.loadApps,
            fetchApps: $0.repository.fetchApps,
            saveApps: $0.repository.saveApps,
            deleteAllApps: $0.repository.deleteAllApps
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
            fetchApps: $0.repository.fetchApps,
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
              publisher: environment.repository.publisher()
            ),
            updates: PublisherEnvironment(
              publisher: systemEnvironment.repository.updates()
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

      case let .updates(.receivedUpdates(.success(updatedApps), at: date)):
        return .fireAndForget {
          environment.repository.saveApps(updatedApps)
          environment.settings.lastUpdateDate = date
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
}
