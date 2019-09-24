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
}

public extension UserDefault {
  var defaultValue: Value { key.defaultValue }
  var exists: Bool { defaults.has(key) }
  var publisher: UserDefaults.Publisher<Value> { defaults.publisher(for: key) }
}
