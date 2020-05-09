import Combine
import ComposableArchitecture
import Foundation
import WishlistData

struct URLSchemeState: Equatable {
  var apps: [App]
  var viewingAppDetails: App.ID? = nil
  var loadingApps: Bool = false
}

enum URLSchemeAction {
  case handleURLScheme(URLScheme)
  case addAppsResponse(Result<[App], Error>)
}

struct URLSchemeEnvironment {
  let loadApps: ([App.ID]) -> AnyPublisher<[App], Error>
  let mainQueue: AnySchedulerOf<DispatchQueue>
}

let urlSchemeReducer = Reducer<URLSchemeState, URLSchemeAction, URLSchemeEnvironment> { state, action, environment in
  switch action {
  case .addAppsResponse(let result):
    state.loadingApps = false
    if case let .success(apps) = result {
      state.apps.append(contentsOf: apps)
    }
    return .none
  case .handleURLScheme(let urlScheme):
    switch urlScheme {
    case .addApps(let ids):
      state.loadingApps = true
      return environment.loadApps(ids)
        .receive(on: environment.mainQueue)
        .catchToEffect()
        .map(URLSchemeAction.addAppsResponse)
    case .viewApp(let id):
      state.viewingAppDetails = id
      return .none
    case .export:
      let addAppsURLScheme = URLScheme.addApps(ids: state.apps.map(\.id))
      return .fireAndForget {
        print(addAppsURLScheme.rawValue)
      }
    case .deleteAll:
      state.apps = []
      return .none
    }
  }
}
