import Foundation
import Combine

@available(iOS 13.0, *)
public extension UserDefaults {
  func publisher<Value: UserDefaultsSerializable>(for key: Key<Value>) -> UserDefaults.Publisher<Value> {
    UserDefaults.Publisher(defaults: self, key: key)
  }

  struct Publisher<Output: UserDefaultsSerializable>: Combine.Publisher {
    public typealias Failure = Never

    public let defaults: UserDefaults
    public let key: Key<Output>

    public init(defaults: UserDefaults, key: Key<Output>) {
      self.defaults = defaults
      self.key = key
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Output == S.Input, Failure == S.Failure {
      let observer = UserDefaults.Observer(defaults: defaults, key: key)
      observer
        .subject
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

    init(defaults: UserDefaults, key: Key<Value>) {
      self.defaults = defaults
      self.key = key
      super.init()
    }

    func start() {
      defaults.addObserver(self, forKeyPath: key.key, options: [], context: nil)
    }

    func stop() {
      defaults.removeObserver(self, forKeyPath: key.key)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
      guard
        let kindKey = change?[NSKeyValueChangeKey.kindKey] as? NSNumber,
        let valueChange = NSKeyValueChange(rawValue: kindKey.uintValue),
        valueChange == .setting
      else {
        return
      }

      subject.send(defaults[key])
    }
  }
}
