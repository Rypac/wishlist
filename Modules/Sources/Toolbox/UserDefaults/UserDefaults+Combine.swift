import Foundation
import Combine

public extension UserDefaults {
  func publisher<Value>(for key: UserDefaultsKey<Value>) -> UserDefaults.Publisher<Value> {
    UserDefaults.Publisher(key: key, defaults: self)
  }

  struct Publisher<Output>: Combine.Publisher {
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

  private final class Subscription<S: Subscriber>: NSObject, Combine.Subscription {
    private var subscriber: S?
    private var requested: Subscribers.Demand = .none
    private var defaultsObserverToken: NSObject? = nil

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
