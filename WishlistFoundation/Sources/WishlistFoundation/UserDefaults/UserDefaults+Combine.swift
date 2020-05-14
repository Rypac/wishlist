import Foundation
import Combine

@available(iOS 13.0, *)
public extension UserDefaults {
  func publisher<Value: UserDefaultsSerializable>(for key: Key<Value>, initialValue: InitialValueStrategy = .include) -> UserDefaults.Publisher<Value> {
    UserDefaults.Publisher(defaults: self, key: key, initialValue: initialValue)
  }

  enum InitialValueStrategy {
    case skip
    case include
  }

  struct Publisher<Output: UserDefaultsSerializable>: Combine.Publisher {
    public typealias Failure = Never

    public let defaults: UserDefaults
    public let key: Key<Output>
    public let initialValue: InitialValueStrategy

    public init(defaults: UserDefaults, key: Key<Output>, initialValue: InitialValueStrategy = .skip) {
      self.defaults = defaults
      self.key = key
      self.initialValue = initialValue
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Output == S.Input, Failure == S.Failure {
      let observer = UserDefaults.Observer(defaults: defaults, key: key, initialValue: initialValue)
      observer
        .subject
        .buffer(size: 1, prefetch: .keepFull, whenFull: .dropOldest)
        .handleEvents(
          receiveSubscription: { _ in observer.start() },
          receiveCancel: { observer.stop() }
        )
        .receive(subscriber: subscriber)
    }
  }

  private final class Observer<Value: UserDefaultsSerializable>: NSObject {
    let subject = PassthroughSubject<Value, Never>()

    private let defaults: UserDefaults
    private let key: Key<Value>
    private let initialValue: InitialValueStrategy

    init(defaults: UserDefaults, key: Key<Value>, initialValue: InitialValueStrategy) {
      self.defaults = defaults
      self.key = key
      self.initialValue = initialValue
      super.init()
    }

    func start() {
      let options = initialValue == .include ? NSKeyValueObservingOptions.initial : []
      defaults.addObserver(self, forKeyPath: key.key, options: options, context: nil)
    }

    func stop() {
      defaults.removeObserver(self, forKeyPath: key.key)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
      subject.send(defaults[key])
    }
  }
}
