import Foundation
import Combine

public extension UserDefaults {
  func publisher<Value>(
    for key: Key<Value>,
    adapter: UserDefaultsAdapter<Value>,
    initialValue: InitialValueStrategy = .include
  ) -> UserDefaults.Publisher<Value> {
    UserDefaults.Publisher(defaults: self, key: key, adapter: adapter, initialValue: initialValue)
  }

  enum InitialValueStrategy {
    case skip
    case include
  }

  struct Publisher<Output>: Combine.Publisher {
    public typealias Failure = Never

    private let defaults: UserDefaults
    private let key: Key<Output>
    private let adapter: UserDefaultsAdapter<Output>
    private let initialValue: InitialValueStrategy

    public init(
      defaults: UserDefaults,
      key: Key<Output>,
      adapter: UserDefaultsAdapter<Output>,
      initialValue: InitialValueStrategy
    ) {
      self.defaults = defaults
      self.key = key
      self.adapter = adapter
      self.initialValue = initialValue
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Output == S.Input, Failure == S.Failure {
      let observer = UserDefaults.Observer(defaults: defaults, key: key, adapter: adapter, initialValue: initialValue)
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

  private final class Observer<Value>: NSObject {
    let subject = PassthroughSubject<Value, Never>()

    private let defaults: UserDefaults
    private let key: Key<Value>
    private let adapter: UserDefaultsAdapter<Value>
    private let initialValue: InitialValueStrategy

    init(
      defaults: UserDefaults,
      key: Key<Value>,
      adapter: UserDefaultsAdapter<Value>,
      initialValue: InitialValueStrategy
    ) {
      self.defaults = defaults
      self.key = key
      self.adapter = adapter
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
      subject.send(adapter.get(defaults, key.key) ?? key.defaultValue)
    }
  }
}
