import Combine

extension AnyPublisher {
  public static func just(_ value: Output) -> AnyPublisher<Output, Failure> {
    Just(value).setFailureType(to: Failure.self).eraseToAnyPublisher()
  }

  public static func empty(completeImmediately: Bool = true) -> AnyPublisher<Output, Failure> {
    Empty().eraseToAnyPublisher()
  }

  public static func never() -> AnyPublisher<Output, Failure> {
    Empty(completeImmediately: false).eraseToAnyPublisher()
  }
}
