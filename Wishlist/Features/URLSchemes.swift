import Combine
import ComposableArchitecture
import Foundation
import WishlistModel

struct URLSchemeState: Equatable {
  var apps: [App]
  var viewingAppDetails: App.ID?
}

enum URLSchemeAction {
  case handleURLScheme(URLScheme)
  case addApps(AddAppsAction)
}

struct URLSchemeEnvironment {
  let loadApps: ([App.ID]) -> AnyPublisher<[App], Error>
}

let urlSchemeReducer = Reducer<URLSchemeState, URLSchemeAction, SystemEnvironment<URLSchemeEnvironment>>.combine(
  Reducer { state, action, environment in
    switch action {
    case let .handleURLScheme(.addApps(ids)):
      return Effect(value: .addApps(.addApps(ids)))

    case let .handleURLScheme(.viewApp(id)):
      state.viewingAppDetails = id
      return .none

    case .handleURLScheme(.export):
      let addAppsURLScheme = URLScheme.addApps(ids: state.apps.map(\.id))
      return .fireAndForget {
        print(addAppsURLScheme.rawValue)
      }

    case .handleURLScheme(.deleteAll):
      state.apps = []
      return .none

    case .addApps:
      return .none
    }
  },
  addAppsReducer.pullback(
    state: \.addAppsState,
    action: /URLSchemeAction.addApps,
    environment: { systemEnvironment in
      systemEnvironment.map {
        AddAppsEnvironment(loadApps: $0.loadApps)
      }
    }
  )
)

private extension URLSchemeState {
  var addAppsState: AddAppsState {
    get { AddAppsState(apps: apps) }
    set { apps = newValue.apps }
  }
}
