import ComposableArchitecture
import Combine
import Foundation

typealias PublisherState<T: Equatable> = T

enum PublisherAction<T> {
  case subscribe
  case receivedValue(T)
}

struct PublisherEnvironment<T> {
  var publisher: AnyPublisher<T, Never>
  var perform: (T) -> Void
}

extension PublisherEnvironment {
  init(publisher: AnyPublisher<T, Never>) {
    self.init(publisher: publisher, perform: { _ in })
  }
}

func publisherReducer<T>() -> Reducer<PublisherState<T>, PublisherAction<T>, SystemEnvironment<PublisherEnvironment<T>>> {
  Reducer { state, action, environment in
    switch action {
    case .subscribe:
      return environment.publisher
        .removeDuplicates()
        .receive(on: environment.mainQueue())
        .eraseToEffect()
        .map(PublisherAction.receivedValue)

    case let .receivedValue(value):
      guard value != state else {
        return .none
      }

      state = value
      return .fireAndForget {
        environment.perform(value)
      }
    }
  }
}

import WishlistData

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
  },
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
  )
)
