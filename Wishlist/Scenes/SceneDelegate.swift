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
        appListState: AppListState(
          apps: apps,
          sortOrder: appDelegate.settings.sortOrder
        )
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
      handleURLScheme(urlContext.url)
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
      handleURLScheme(urlContext.url)
    }
  }

  private func handleURLScheme(_ url: URL) {
    guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true), let action = components.host else {
      print("Invalid URL or action is missing")
      return
    }

    switch action {
    case "add":
      if let appIDs = components.queryItems?.first(where: { $0.name == "id" })?.value {
        let ids = appIDs.split(separator: ",").compactMap { Int($0, radix: 10) }
        if !ids.isEmpty {
          viewStore.send(.addApps(ids: ids))
        }
      } else {
        print("Add action requires a list of comma separated app IDs")
      }
    case "export":
      do {
        let ids = try appDelegate.appRepository.fetchAll().map { String($0.id) }.joined(separator: ",")
        print("appdates://add?id=\(ids)")
      } catch {
        print("Unable to export apps")
      }
    case "deleteAll":
      do {
        let apps = try appDelegate.appRepository.fetchAll()
        try appDelegate.appRepository.delete(apps)
        print("Deleted all apps")
      } catch {
        print("Unable to delete all apps")
      }
    default:
      print("Unhandled URL scheme action: \(action)")
    }
  }

  private var appDelegate: AppDelegate {
    UIApplication.shared.delegate as! AppDelegate
  }
}

struct AppState: Equatable {
  var appListState: AppListState
}

enum AppLifecycleEvent {
  case didStart
  case didBecomeAction
  case didEnterBackground
}

enum AppAction {
  case appsUpdated([App])
  case appList(AppListAction)
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
    case .addApps(let ids):
      return environment.loadApps(ids)
        .subscribe(on: environment.mainQueue)
        .catchToEffect()
        .map(AppAction.addAppsResponse)
    case .addAppsResponse(.success(let apps)):
      return .fireAndForget {
        try? environment.repository.add(apps)
      }
    case .addAppsResponse(.failure), .appList, .lifecycle:
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
  )
)
