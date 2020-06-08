import ComposableArchitecture
import Combine
import Foundation

public typealias PublisherState<T: Equatable> = T

public enum PublisherAction<T> {
  case subscribe
  case receivedValue(T)
  case unsubscribe
}

public struct PublisherEnvironment<T> {
  public var publisher: (T) -> AnyPublisher<T, Never>
  public var perform: (T) -> Void

  public init(
    publisher: @escaping (T) -> AnyPublisher<T, Never>,
    perform: @escaping (T) -> Void = { _ in }
  ) {
    self.publisher = publisher
    self.perform = perform
  }

  public init(
    publisher: AnyPublisher<T, Never>,
    perform: @escaping (T) -> Void = { _ in }
  ) {
    self.publisher = { _ in publisher }
    self.perform = perform
  }
}

private struct CancelSubscriptionID<T>: Hashable {}

public func publisherReducer<T>() -> Reducer<PublisherState<T>, PublisherAction<T>, SystemEnvironment<PublisherEnvironment<T>>> {
  Reducer { state, action, environment in
    switch action {
    case .subscribe:
      return environment.publisher(state)
        .removeDuplicates()
        .receive(on: environment.mainQueue())
        .eraseToEffect()
        .map(PublisherAction.receivedValue)
        .cancellable(id: CancelSubscriptionID<T>(), cancelInFlight: true)

    case .unsubscribe:
      return .cancel(id: CancelSubscriptionID<T>())

    case let .receivedValue(value):
      state = value
      return .fireAndForget {
        environment.perform(value)
      }
    }
  }
}
