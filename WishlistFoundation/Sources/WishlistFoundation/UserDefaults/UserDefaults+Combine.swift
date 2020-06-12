import Foundation
import Combine

public extension UserDefaults {
  func publisher<Value>(
    for key: UserDefaultsKey<Value>,
    initialValue: InitialValueStrategy = .include
  ) -> UserDefaults.Publisher<Value> {
    UserDefaults.Publisher(key: key, defaults: self, initialValue: initialValue)
  }

  enum InitialValueStrategy {
    case skip
    case include
  }

  struct Publisher<Output>: Combine.Publisher {
    public typealias Failure = Never

    private let key: UserDefaultsKey<Output>
    private let defaults: UserDefaults
    private let initialValue: InitialValueStrategy

    public init(key: UserDefaultsKey<Output>, defaults: UserDefaults, initialValue: InitialValueStrategy) {
      self.defaults = defaults
      self.key = key
      self.initialValue = initialValue
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Output == S.Input, Failure == S.Failure {
      let observer = UserDefaults.Observer(key: key, defaults: defaults, initialValue: initialValue)
      observer
        .subject
        .buffer(size: 1, prefetch: .keepFull, whenFull: .dropOldest)
        .handleEvents(
          receiveSubscription: { _ in observer.start() },
          receiveCompletion: { _ in observer.stop() },
          receiveCancel: { observer.stop() }
        )
        .receive(subscriber: subscriber)
    }
  }

  private final class Observer<Value>: NSObject {
    let subject = PassthroughSubject<Value, Never>()

    private let key: UserDefaultsKey<Value>
    private let defaults: UserDefaults
    private let initialValue: InitialValueStrategy

    init(key: UserDefaultsKey<Value>, defaults: UserDefaults, initialValue: InitialValueStrategy) {
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
