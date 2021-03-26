import Combine
import ComposableArchitecture
import Foundation
import Domain

struct URLSchemeState: Equatable {
  var addAppsState: AddAppsState
  var viewingAppDetails: AppID?
}

enum URLSchemeAction {
  case handleURLScheme(URLScheme)
  case addApps(AddAppsAction)
}

struct URLSchemeEnvironment {
  var loadApps: ([AppID]) -> AnyPublisher<[AppSummary], Error>
  var fetchApps: () throws -> [AppSummary]
  var saveApps: ([AppSummary]) throws -> Void
  var deleteAllApps: () throws -> Void
}

let urlSchemeReducer = Reducer<URLSchemeState, URLSchemeAction, SystemEnvironment<URLSchemeEnvironment>>.combine(
  addAppsReducer.pullback(
    state: \.addAppsState,
    action: /URLSchemeAction.addApps,
    environment: { systemEnvironment in
      systemEnvironment.map {
        AddAppsEnvironment(
          loadApps: $0.loadApps,
          saveApps: $0.saveApps
        )
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
      return .fireAndForget {
        if let apps = try? environment.fetchApps() {
          let addAppsURLScheme = URLScheme.addApps(ids: apps.map(\.id))
          print(addAppsURLScheme.rawValue)
        }
      }

    case .handleURLScheme(.deleteAll):
      return .fireAndForget {
        try? environment.deleteAllApps()
      }

    case .addApps:
      return .none
    }
  }
)
