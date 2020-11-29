import Combine
import ComposableArchitecture
import Foundation
import Domain

struct URLSchemeState: Equatable {
  var apps: [AppDetails]
  var viewingAppDetails: AppID?
}

enum URLSchemeAction {
  case handleURLScheme(URLScheme)
  case addApps(AddAppsAction)
}

struct URLSchemeEnvironment {
  let loadApps: ([AppID]) -> AnyPublisher<[AppSummary], Error>
}

let urlSchemeReducer = Reducer<URLSchemeState, URLSchemeAction, SystemEnvironment<URLSchemeEnvironment>>.combine(
  addAppsReducer.pullback(
    state: \.addAppsState,
    action: /URLSchemeAction.addApps,
    environment: { systemEnvironment in
      systemEnvironment.map {
        AddAppsEnvironment(loadApps: $0.loadApps)
      }
    }
  ),
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
  }
)

private extension URLSchemeState {
  var addAppsState: AddAppsState {
    get { AddAppsState(apps: apps) }
    set { apps = newValue.apps }
  }
}
