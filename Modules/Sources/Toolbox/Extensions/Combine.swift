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

extension Publisher {
  public func scan<Result>(
    into initialResult: Result,
    _ nextPartialResult: @escaping (inout Result, Output) -> Void
  ) -> Publishers.ScanInto<Self, Result> {
    Publishers.ScanInto(upstream: self, initialResult: initialResult, nextPartialResult: nextPartialResult)
  }
}

extension Publishers {
  public struct ScanInto<Upstream: Publisher, Output>: Publisher {
    public typealias Failure = Upstream.Failure

    public let upstream: Upstream
    public let initialResult: Output
    public let nextPartialResult: (inout Output, Upstream.Output) -> Void

    public init(
      upstream: Upstream,
      initialResult: Output,
      nextPartialResult: @escaping (inout Output, Upstream.Output) -> Void
    ) {
      self.upstream = upstream
      self.initialResult = initialResult
      self.nextPartialResult = nextPartialResult
    }

    public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Output == Downstream.Input, Upstream.Failure == Downstream.Failure {
      let subscription = Subscription(
        downstream: subscriber,
        initialResult: initialResult,
        nextPartialResult: nextPartialResult
      )
      upstream.subscribe(subscription)
    }
  }
}

extension Publishers.ScanInto {
  private final class Subscription<Downstream: Subscriber>: Subscriber where Upstream.Failure == Downstream.Failure {
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure

    private let downstream: Downstream
    private let nextPartialResult: (inout Downstream.Input, Input) -> Void
    private var result: Downstream.Input

    fileprivate init(
      downstream: Downstream,
      initialResult: Downstream.Input,
      nextPartialResult: @escaping (inout Downstream.Input, Input) -> Void
    ) {
      self.downstream = downstream
      self.result = initialResult
      self.nextPartialResult = nextPartialResult
    }

    func receive(subscription: Combine.Subscription) {
      downstream.receive(subscription: subscription)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
      nextPartialResult(&result, input)
      return downstream.receive(result)
    }

    func receive(completion: Subscribers.Completion<Failure>) {
      downstream.receive(completion: completion)
    }
  }
}
