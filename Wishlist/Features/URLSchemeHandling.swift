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

let urlSchemeReducer = Reducer<URLSchemeState, URLSchemeAction, URLSchemeEnvironment>.strict { state, action in
  switch action {
  case let .addAppsResponse(result):
    state.loadingApps = false
    if case let .success(apps) = result {
      state.apps.append(contentsOf: apps)
    }
    return { _ in .none }
  case let .handleURLScheme(.addApps(ids)):
    state.loadingApps = true
    return { environment in
      environment.loadApps(ids)
        .receive(on: environment.mainQueue)
        .catchToEffect()
        .map(URLSchemeAction.addAppsResponse)
    }
  case let .handleURLScheme(.viewApp(id)):
    state.viewingAppDetails = id
    return { _ in .none }
  case .handleURLScheme(.export):
    let addAppsURLScheme = URLScheme.addApps(ids: state.apps.map(\.id))
    return { environment in
      .fireAndForget {
        print(addAppsURLScheme.rawValue)
      }
    }
  case .handleURLScheme(.deleteAll):
    state.apps = []
    return { _ in .none }
  }
}
