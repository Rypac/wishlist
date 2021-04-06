import Foundation

@propertyWrapper
public struct UserDefault<Value> {
  private let key: UserDefaultsKey<Value>
  private let defaults: UserDefaults

  public init(_ key: UserDefaultsKey<Value>, userDefaults: UserDefaults = .standard) {
    self.key = key
    self.defaults = userDefaults
  }

  public var wrappedValue: Value {
    get { defaults[key] }
    set { defaults[key] = newValue }
  }

  public var projectedValue: UserDefault<Value> {
    self
  }

  public func register() {
    defaults.register(key)
  }

  public func publisher() -> UserDefaults.Publisher<Value> {
    defaults.publisher(for: key)
  }

  public func subject() -> UserDefaults.Subject<Value> {
    defaults.subject(for: key)
  }
}

public extension UserDefault where Value: UserDefaultsConvertible {
  init(_ key: String, defaultValue: Value, userDefaults: UserDefaults = .standard) {
    self.key = UserDefaultsKey(key, defaultValue: defaultValue)
    self.defaults = userDefaults
  }

  init<Wrapped>(_ key: String, userDefaults: UserDefaults = .standard) where Value == Wrapped? {
    self.key = UserDefaultsKey(key, defaultValue: nil)
    self.defaults = userDefaults
  }
}

public extension UserDefault where Value: Codable {
  init(
    _ key: String,
    defaultValue: Value,
    userDefaults: UserDefaults = .standard,
    encoder: JSONEncoder = JSONEncoder(),
    decoder: JSONDecoder = JSONDecoder()
  ) {
    self.key = UserDefaultsKey(key, defaultValue: defaultValue, encoder: encoder, decoder: decoder)
    self.defaults = userDefaults
  }
}
