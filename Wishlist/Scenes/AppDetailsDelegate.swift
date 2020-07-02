import Combine
import ComposableArchitecture
import SwiftUI
import UIKit
import WishlistCore
import WishlistFoundation

class AppDetailsDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  var session: UISceneSession?

  private lazy var store: Store<AppDetailsSceneState, AppDetailsSceneAction> = {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    return Store(
      initialState: AppDetailsSceneState(theme: appDelegate.settings.theme),
      reducer: appDetailsSceneReducer(id: UUID()),
      environment: .live(
        environment: AppDetailsSceneEnvironment(
          repository: appDelegate.appRepository,
          theme: appDelegate.settings.$theme.publisher().eraseToAnyPublisher(),
          applyTheme: { [weak self] theme in
            self?.window?.overrideUserInterfaceStyle = UIUserInterfaceStyle(theme)
          },
          openURL: { UIApplication.shared.open($0) },
          terminate: { [weak self] in
            if let session = self?.session {
              UIApplication.shared.requestSceneSessionDestruction(session, options: nil)
            }
          }
        )
      )
    )
  }()
  private lazy var viewStore = ViewStore(store)

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let detailsScene = session.userInfo.flatMap(DetailsScene.init) else {
      print("Attempted to show scene with invalid scene configuration.")
      UIApplication.shared.requestSceneSessionDestruction(session, options: nil)
      return
    }

    let window = UIWindow(windowScene: scene as! UIWindowScene)
    window.rootViewController = UIHostingController(
      rootView: AppDetailsNavigationView(store: store)
    )
    self.window = window
    self.session = session
    window.makeKeyAndVisible()

    viewStore.send(.lifecycle(.willConnect))
    viewStore.send(.viewApp(detailsScene.id))
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
}

private struct AppDetailsNavigationView: View {
  let store: Store<AppDetailsSceneState, AppDetailsSceneAction>

  var body: some View {
    WithViewStore(store.stateless) { viewStore in
      NavigationView {
        IfLetStore(
          self.store.scope(state: \.details, action: AppDetailsSceneAction.details),
          then: AppDetailsContentView.init
        )
          .navigationBarTitle("Details", displayMode: .inline)
          .navigationBarItems(
            trailing: Button("Close") {
              viewStore.send(.closeDetails)
            }.hoverEffect()
          )
      }.navigationViewStyle(StackNavigationViewStyle())
    }
  }
}

struct AppDetailsSceneState: Equatable {
  var details: AppDetailsState?
  var theme: Theme
}

enum AppDetailsSceneAction {
  case viewApp(WishlistFoundation.App.ID)
  case details(AppDetailsAction)
  case lifecycle(SceneLifecycleEvent)
  case theme(PublisherAction<Theme>)
  case app(PublisherAction<[WishlistFoundation.App]>)
  case closeDetails
}

struct AppDetailsSceneEnvironment {
  var repository: AppRepository
  var theme: AnyPublisher<Theme, Never>
  var applyTheme: (Theme) -> Void
  var openURL: (URL) -> Void
  var terminate: () -> Void
}

private extension AppDetailsSceneState {
  var app: WishlistFoundation.App? {
    get { details?.app }
    set {
      if let app = newValue {
        details?.app = app
      }
    }
  }
}

private struct ProcessID<T>: Hashable {
  let id: AnyHashable

  init(_ id: AnyHashable) {
    self.id = id
  }
}

func appDetailsSceneReducer(
  id: AnyHashable
) -> Reducer<AppDetailsSceneState, AppDetailsSceneAction, SystemEnvironment<AppDetailsSceneEnvironment>> {
  .combine(
    publisherReducer(id: ProcessID<Theme>(id)).pullback(
       state: \.theme,
       action: /AppDetailsSceneAction.theme,
       environment: { systemEnvironment in
         systemEnvironment.map {
           PublisherEnvironment(publisher: $0.theme, perform: $0.applyTheme)
         }
       }
    ),
    appUpdatesReducer(id: ProcessID<WishlistFoundation.App>(id)).optional.pullback(
      state: \.app,
      action: /AppDetailsSceneAction.app,
      environment: { systemEnvironment in
        systemEnvironment.map {
          PublisherEnvironment(publisher: $0.repository.updates())
        }
      }
    ),
    appDetailsReducer.optional.pullback(
      state: \.details,
      action: /AppDetailsSceneAction.details,
      environment: { systemEnvironment in
        systemEnvironment.map {
          AppDetailsEnvironment(
            openURL: $0.openURL,
            versionHistory: { id in
              (try? systemEnvironment.repository.versionHistory(id: id)) ?? []
            },
            saveNotifications: { id, notifications in
              try? systemEnvironment.repository.notify(id: id, for: notifications)
            }
          )
        }
      }
    ),
    Reducer { state, action, environment in
      switch action {
      case .lifecycle(.willEnterForeground):
        return .merge(
          Effect(value: .theme(.subscribe)),
          Effect(value: .app(.subscribe))
        )

      case .lifecycle(.didEnterBackground):
        return .merge(
          Effect(value: .theme(.unsubscribe)),
          Effect(value: .app(.unsubscribe))
        )

      case let .viewApp(id):
        state.details = try? environment.repository.fetch(id: id).map {
          AppDetailsState(app: $0, versions: nil, showVersionHistory: false)
        }
        return .none

      case .closeDetails:
        return .fireAndForget {
          environment.terminate()
        }

      case .lifecycle, .details, .theme, .app:
        return .none
      }
    }
  )
}

private func appUpdatesReducer(
  id: AnyHashable
) -> Reducer<WishlistFoundation.App, PublisherAction<[WishlistFoundation.App]>, SystemEnvironment<PublisherEnvironment<[WishlistFoundation.App]>>> {
  Reducer { state, action, environment in
    switch action {
    case .subscribe:
      return environment.publisher
        .receive(on: environment.mainQueue())
        .eraseToEffect()
        .map(PublisherAction.receivedValue)
        .cancellable(id: id, cancelInFlight: true)

    case .unsubscribe:
      return .cancel(id: id)

    case let .receivedValue(apps):
      for app in apps where app.id == state.id {
        state = app
      }
      return .none
    }
  }
}
