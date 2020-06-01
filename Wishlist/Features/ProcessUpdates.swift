import ComposableArchitecture
import Combine
import Foundation
import WishlistCore
import WishlistFoundation

struct ProcessUpdateState: Equatable {
  var apps: [App]
  var sortOrder: SortOrder
  var theme: Theme
}

enum ProcessUpdateAction {
  case subscribe
  case apps(PublisherAction<[App]>)
  case sortOrder(PublisherAction<SortOrder>)
  case theme(PublisherAction<Theme>)
}

struct ProcessUpdateEnvironment {
  var apps: PublisherEnvironment<[App]>
  var sortOrder: PublisherEnvironment<SortOrder>
  var theme: PublisherEnvironment<Theme>
}

let processUpdateReducer = Reducer<ProcessUpdateState, ProcessUpdateAction, SystemEnvironment<ProcessUpdateEnvironment>>.combine(
  publisherReducer().pullback(
    state: \.apps,
    action: /ProcessUpdateAction.apps,
    environment: { $0.map(\.apps) }
  ),
  publisherReducer().pullback(
    state: \.sortOrder,
    action: /ProcessUpdateAction.sortOrder,
    environment: { $0.map(\.sortOrder) }
  ),
  publisherReducer().pullback(
    state: \.theme,
    action: /ProcessUpdateAction.theme,
    environment: { $0.map(\.theme) }
  ),
  Reducer { state, action, environment in
    switch action {
    case .subscribe:
      return .merge(
        Effect(value: .apps(.subscribe)),
        Effect(value: .sortOrder(.subscribe)),
        Effect(value: .theme(.subscribe))
      )

    case .apps, .sortOrder, .theme:
      return .none
    }
  }
)
