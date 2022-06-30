import Combine
import Foundation

@propertyWrapper
public struct UserDefault<Value: UserDefaultsConvertible> {
  private let _key: UserDefaultsKey<Value>
  private let userDefaults: UserDefaults

  public init(_ key: String, defaultValue: Value, userDefaults: UserDefaults = .standard) {
    self._key = UserDefaultsKey(key, defaultValue: defaultValue)
    self.userDefaults = userDefaults
  }

  public init(_ key: UserDefaultsKey<Value>, userDefaults: UserDefaults = .standard) {
    self._key = key
    self.userDefaults = userDefaults
  }

  public var wrappedValue: Value {
    get { userDefaults[_key] }
    nonmutating set { userDefaults[_key] = newValue }
  }

  public var projectedValue: UserDefault<Value> { self }

  public var key: String { _key.key }

  public var defaultValue: Value { _key.defaultValue }

  public func register() {
    userDefaults.register(_key)
  }

  public func publisher() -> some Publisher<Value, Never> {
    userDefaults.publisher(for: _key)
  }

  public func subject() -> some Subject<Value, Never> {
    userDefaults.subject(for: _key)
  }
}

@propertyWrapper
public struct OptionalUserDefault<Value: UserDefaultsConvertible> {
  private let _key: UserDefaultsKey<Value?>
  private let userDefaults: UserDefaults

  public init(_ key: String, defaultValue: Value? = nil, userDefaults: UserDefaults = .standard) {
    self._key = UserDefaultsKey(key, defaultValue: defaultValue)
    self.userDefaults = userDefaults
  }

  public init(_ key: UserDefaultsKey<Value?>, userDefaults: UserDefaults = .standard) {
    self._key = key
    self.userDefaults = userDefaults
  }

  public var wrappedValue: Value? {
    get { userDefaults[_key] }
    nonmutating set { userDefaults[_key] = newValue }
  }

  public var projectedValue: OptionalUserDefault<Value> { self }

  public var key: String { _key.key }

  public var defaultValue: Value? { _key.defaultValue }
}
