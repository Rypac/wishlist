import Foundation
import Combine

// MARK: - Publisher

extension UserDefaults {
  public func publisher<Value: UserDefaultsCodable>(for key: UserDefaultsKey<Value>) -> UserDefaults.Publisher<Value> {
    UserDefaults.Publisher(key: key, defaults: self)
  }

  public struct Publisher<Output: UserDefaultsCodable>: Combine.Publisher {
    public typealias Failure = Never

    private let key: UserDefaultsKey<Output>
    private let defaults: UserDefaults

    public init(key: UserDefaultsKey<Output>, defaults: UserDefaults) {
      self.defaults = defaults
      self.key = key
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Output == S.Input, Failure == S.Failure {
      let subscription = Subscription(subscriber: subscriber, key: key, defaults: defaults)
      subscriber.receive(subscription: subscription)
    }
  }
}

// MARK: - Subject

extension UserDefaults {
  public func subject<Value: UserDefaultsCodable>(for key: UserDefaultsKey<Value>) -> UserDefaults.Subject<Value> {
    UserDefaults.Subject(key: key, defaults: self)
  }

  public final class Subject<Output: UserDefaultsCodable>: Combine.Subject {
    public typealias Failure = Never

    private let key: UserDefaultsKey<Output>
    private let defaults: UserDefaults

    private var isActive = true

    public init(key: UserDefaultsKey<Output>, defaults: UserDefaults) {
      self.defaults = defaults
      self.key = key
    }

    public var value: Output {
      defaults[key]
    }

    public func send(_ value: Output) {
      defaults[key] = value
    }

    public func send(completion: Subscribers.Completion<Failure>) {
      isActive = false
    }

    public func send(subscription: Combine.Subscription) {
      subscription.request(.unlimited)
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Output == S.Input, Failure == S.Failure {
      if isActive {
        let subscription = Subscription(subscriber: subscriber, key: key, defaults: defaults)
        subscriber.receive(subscription: subscription)
      } else {
        subscriber.receive(subscription: Subscriptions.empty)
        subscriber.receive(completion: .finished)
      }
    }
  }
}

// MARK: - Subscription

private extension UserDefaults {
  final class Subscription<S: Subscriber>: NSObject, Combine.Subscription where S.Input: UserDefaultsCodable {
    private var subscriber: S?
    private var requested: Subscribers.Demand = .none
    private var defaultsObserverToken: NSObject?

    private let key: UserDefaultsKey<S.Input>
    private let defaults: UserDefaults

    private let lock = NSRecursiveLock()

    init(subscriber: S, key: UserDefaultsKey<S.Input>, defaults: UserDefaults) {
      self.subscriber = subscriber
      self.defaults = defaults
      self.key = key
      super.init()
    }

    func request(_ demand: Subscribers.Demand) {
      lock.lock()
      defer { lock.unlock() }
      requested += demand
      guard defaultsObserverToken == nil, requested > .none else {
        return
      }

      defaultsObserverToken = self
      defaults.addObserver(self, forKeyPath: key.key, options: [.initial], context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
      lock.lock()
      defer { lock.unlock() }
      guard let subscriber = subscriber, requested > .none else {
        return
      }

      requested -= .max(1)
      let newDemand = subscriber.receive(defaults[key])
      requested += newDemand
    }

    func cancel() {
      lock.lock()
      defer { lock.unlock() }
      if let token = defaultsObserverToken {
        defaults.removeObserver(token, forKeyPath: key.key)
      }
      defaultsObserverToken = nil
      subscriber = nil
    }
  }
}
