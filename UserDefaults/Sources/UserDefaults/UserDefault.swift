import Foundation
import Combine

@propertyWrapper
public struct UserDefault<Value: UserDefaultsSerializable> {
  public let key: UserDefaults.Key<Value>
  public let defaults: UserDefaults

  public init(key: String, defaultValue: Value, userDefaults: UserDefaults = .standard) {
    self.key = UserDefaults.Key(key: key, defaultValue: defaultValue)
    self.defaults = userDefaults
  }

  public var wrappedValue: Value {
    get { defaults[key] }
    set { defaults[key] = newValue }
  }

  public var projectedValue: UserDefault<Value> { self }

  public var defaultValue: Value { key.defaultValue }

  public var exists: Bool { defaults.has(key) }

  @available(iOS 13.0, *)
  public func publisher(initialValue: UserDefaults.InitialValueStrategy = .skip) -> UserDefaults.Publisher<Value> {
    defaults.publisher(for: key, initialValue: initialValue)
  }
}
