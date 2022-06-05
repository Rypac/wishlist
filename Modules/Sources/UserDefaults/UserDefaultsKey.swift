import Foundation

public struct UserDefaultsKey<Value> {
  public let key: String
  public let defaultValue: Value

  public init(_ key: String, defaultValue: Value) {
    self.key = key
    self.defaultValue = defaultValue
  }
}

extension UserDefaultsKey {
  public init<Wrapped>(_ key: String) where Value == Wrapped? {
    self.key = key
    self.defaultValue = nil
  }
}

extension UserDefaults {
  public func register<Value: UserDefaultsConvertible>(_ keys: UserDefaultsKey<Value>...) {
    register(defaults: keys.reduce(into: Dictionary(minimumCapacity: keys.count)) { defaults, key in
      defaults[key.key] = key.defaultValue.storedValue
    })
  }

  public subscript<Value: UserDefaultsConvertible>(key: UserDefaultsKey<Value>) -> Value {
    get { self[key.key] ?? key.defaultValue }
    set { self[key.key] = newValue }
  }

  public subscript<Value: UserDefaultsConvertible>(key: UserDefaultsKey<Value?>) -> Value? {
    get { self[key.key] ?? key.defaultValue }
    set { self[key.key] = newValue }
  }

  public func has<Value>(_ key: UserDefaultsKey<Value>) -> Bool {
    object(forKey: key.key) != nil
  }

  public func remove<Value>(_ key: UserDefaultsKey<Value>) {
    removeObject(forKey: key.key)
  }
}
