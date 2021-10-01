import Foundation

@propertyWrapper
public struct UserDefault<Value: UserDefaultsSerializable> {
  private let key: UserDefaultsKey<Value>
  private let userDefaults: UserDefaults

  public init(_ key: UserDefaultsKey<Value>, userDefaults: UserDefaults = .standard) {
    self.key = key
    self.userDefaults = userDefaults
  }

  public var wrappedValue: Value {
    get { userDefaults[key] }
    nonmutating set { userDefaults[key] = newValue }
  }

  public var projectedValue: UserDefault<Value> {
    self
  }

  public func register() {
    userDefaults.register(key)
  }

  public func publisher() -> UserDefaults.Publisher<Value> {
    userDefaults.publisher(for: key)
  }

  public func subject() -> UserDefaults.Subject<Value> {
    userDefaults.subject(for: key)
  }
}

extension UserDefault {
  public init(_ key: String, defaultValue: Value, userDefaults: UserDefaults = .standard) {
    self.key = UserDefaultsKey(key, defaultValue: defaultValue)
    self.userDefaults = userDefaults
  }

  public init<Wrapped>(_ key: String, userDefaults: UserDefaults = .standard) where Value == Wrapped? {
    self.key = UserDefaultsKey(key, defaultValue: nil)
    self.userDefaults = userDefaults
  }
}
