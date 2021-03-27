import ComposableArchitecture
import Combine
import Foundation
import Domain

struct ProcessUpdateState: Equatable {
  var apps: IdentifiedArrayOf<AppDetails>
  var sortOrder: SortOrder
  var theme: Theme
}

enum ProcessUpdateAction {
  case subscribe
  case unsubscribe
  case apps(PublisherAction<[AppDetails]>)
  case sortOrder(PublisherAction<SortOrder>)
  case theme(PublisherAction<Theme>)
}

struct ProcessUpdateEnvironment {
  var apps: PublisherEnvironment<[AppDetails]>
  var sortOrder: PublisherEnvironment<SortOrder>
  var theme: PublisherEnvironment<Theme>
}

private struct ProcessID<T>: Hashable {
  let id: AnyHashable

  init(_ id: AnyHashable) {
    self.id = id
  }
}

func processUpdateReducer(
  id: AnyHashable
) -> Reducer<ProcessUpdateState, ProcessUpdateAction, SystemEnvironment<ProcessUpdateEnvironment>> {
  .combine(
    appUpdatesReducer(id: ProcessID<IdentifiedArrayOf<AppDetails>>(id)).pullback(
      state: \.apps,
      action: /ProcessUpdateAction.apps,
      environment: { $0.map(\.apps) }
    ),
    publisherReducer(id: ProcessID<SortOrder>(id)).pullback(
      state: \.sortOrder,
      action: /ProcessUpdateAction.sortOrder,
      environment: { $0.map(\.sortOrder) }
    ),
    publisherReducer(id: ProcessID<Theme>(id)).pullback(
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

      case .unsubscribe:
        return .merge(
          Effect(value: .apps(.unsubscribe)),
          Effect(value: .sortOrder(.unsubscribe)),
          Effect(value: .theme(.unsubscribe))
        )

      case .apps, .sortOrder, .theme:
        return .none
      }
    }
  )
}

private func appUpdatesReducer(
  id: AnyHashable
) -> Reducer<IdentifiedArrayOf<AppDetails>, PublisherAction<[AppDetails]>, SystemEnvironment<PublisherEnvironment<[AppDetails]>>> {
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
      state = IdentifiedArray(apps)
      return .none
    }
  }
}
