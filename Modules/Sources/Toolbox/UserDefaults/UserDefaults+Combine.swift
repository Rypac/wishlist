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
      let observer = UserDefaults.Observer(key: key, defaults: defaults)
      observer
        .subject
        .handleEvents(
          receiveSubscription: { _ in observer.start() },
          receiveCompletion: { _ in observer.stop() },
          receiveCancel: { observer.stop() }
        )
        .receive(subscriber: subscriber)
    }
  }

  private final class Observer<Value>: NSObject {
    let subject: CurrentValueSubject<Value, Never>

    private let key: UserDefaultsKey<Value>
    private let defaults: UserDefaults

    init(key: UserDefaultsKey<Value>, defaults: UserDefaults) {
      self.defaults = defaults
      self.key = key
      self.subject = CurrentValueSubject(defaults[key])
      super.init()
    }

    func start() {
      defaults.addObserver(self, forKeyPath: key.key, options: [], context: nil)
    }

    func stop() {
      defaults.removeObserver(self, forKeyPath: key.key)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
      subject.send(defaults[key])
    }
  }
}
