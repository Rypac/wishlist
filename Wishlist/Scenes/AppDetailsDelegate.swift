import Combine
import ComposableArchitecture
import SwiftUI
import UIKit
import WishlistModel

class AppDetailsDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?
  var session: UISceneSession?

  private lazy var store: Store<AppDetailsSceneState, AppDetailsSceneAction> = {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    return Store(
      initialState: AppDetailsSceneState(theme: appDelegate.settings.theme),
      reducer: appDetailsSceneReducer,
      environment: .live(
        environment: AppDetailsSceneEnvironment(
          theme: appDelegate.settings.$theme.publisher().eraseToAnyPublisher(),
          applyTheme: { [weak self] theme in
            self?.window?.overrideUserInterfaceStyle = UIUserInterfaceStyle(theme)
          },
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
    if let windowScene = scene as? UIWindowScene, let appDelegate = UIApplication.shared.delegate as? AppDelegate {
      guard
        let id = session.userInfo?[ActivityIdentifier.UserInfoKey.id] as? Int,
        let app = try? appDelegate.appRepository.fetch(id: id)
      else {
        print("Attempted to show scene with invalid app id.")
        UIApplication.shared.requestSceneSessionDestruction(session, options: nil)
        return
      }

      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = UIHostingController(rootView: AppDetailsNavigationView(store: store.stateless, app: app))
      self.window = window
      self.session = session
      window.makeKeyAndVisible()

      viewStore.send(.subscibeToThemeChanges)
    }
  }

  func sceneWillEnterForeground(_ scene: UIScene) {
    viewStore.send(.willBecomeActive)
  }
}

private struct AppDetailsNavigationView: View {
  let store: Store<Void, AppDetailsSceneAction>
  let app: App

  var body: some View {
    WithViewStore(store) { viewStore in
      NavigationView {
        AppDetailsContentView(app: self.app)
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
  var theme: Theme
}

enum AppDetailsSceneAction {
  case subscibeToThemeChanges
  case willBecomeActive
  case themeChanged(PublisherAction<Theme>)
  case closeDetails
}

struct AppDetailsSceneEnvironment {
  var theme: AnyPublisher<Theme, Never>
  var applyTheme: (Theme) -> Void
  var terminate: () -> Void
}

let appDetailsSceneReducer = Reducer<AppDetailsSceneState, AppDetailsSceneAction, SystemEnvironment<AppDetailsSceneEnvironment>>.combine(
  Reducer { state, action, environment in
    switch action {
    case .subscibeToThemeChanges:
      return Effect(value: .themeChanged(.subscribe))

    case .closeDetails:
      return .fireAndForget {
        environment.terminate()
      }

    case .willBecomeActive:
      let theme = state.theme
      return .fireAndForget {
        environment.applyTheme(theme)
      }

    case .themeChanged:
      return .none
    }
  },
  publisherReducer().pullback(
    state: \.theme,
    action: /AppDetailsSceneAction.themeChanged,
    environment: { systemEnvironment in
      systemEnvironment.map {
        PublisherEnvironment(publisher: $0.theme, perform: $0.applyTheme)
      }
    }
  )
)
