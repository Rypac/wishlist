import Combine
import ComposableArchitecture
import Foundation
import WishlistFoundation
import WishlistData

public struct AddAppsState: Equatable {
  public var apps: [App]
}

public enum AddAppsAction {
  case addApps([App.ID])
  case addAppsFromURLs([URL])
  case addAppsResponse(Result<[App], Error>)
}

public struct AddAppsEnvironment {
  public var loadApps: ([App.ID]) -> AnyPublisher<[App], Error>
}

public let addAppsReducer = Reducer<AddAppsState, AddAppsAction, SystemEnvironment<AddAppsEnvironment>> { state, action, environment in
  switch action {
  case let .addApps(ids):
    let ids = Set(ids).subtracting(state.apps.map(\.id))
    if ids.isEmpty {
      return .none
    }

    return environment.loadApps(Array(ids))
      .receive(on: environment.mainQueue())
      .catchToEffect()
      .map(AddAppsAction.addAppsResponse)

  case let .addAppsFromURLs(urls):
    let ids = AppStore.extractIDs(from: urls)
    return ids.isEmpty ? .none : Effect(value: .addApps(ids))

  case let .addAppsResponse(result):
    if case let .success(apps) = result, !apps.isEmpty {
      state.apps.append(contentsOf: apps)
    }
    return .none
  }
}
