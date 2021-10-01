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
  public func register<Value: UserDefaultsSerializable>(_ value: Value, forKey key: String) {
    if let optionalValue = value as? AnyOptional, optionalValue.isNil {
      return
    }

    register(defaults: [key: value.storedValue])
  }

  public func register<Value: UserDefaultsSerializable>(_ key: UserDefaultsKey<Value>) {
    register(key.defaultValue, forKey: key.key)
  }

  public subscript<Value: UserDefaultsCodable>(key: String) -> Value? {
    get { Value.init(from: self, forKey: key) }
    set { newValue.encode(to: self, forKey: key) }
  }

  public subscript<Value: UserDefaultsCodable>(key: UserDefaultsKey<Value>) -> Value {
    get { Value.init(from: self, forKey: key.key) ?? key.defaultValue }
    set { newValue.encode(to: self, forKey: key.key) }
  }

  public func has<Value>(_ key: UserDefaultsKey<Value>) -> Bool {
    object(forKey: key.key) != nil
  }

  public func remove<Value>(_ key: UserDefaultsKey<Value>) {
    removeObject(forKey: key.key)
  }
}

// Inspired from https://www.swiftbysundell.com/articles/property-wrappers-in-swift/
private protocol AnyOptional {
    var isNil: Bool { get }
}

extension Optional: AnyOptional {
    var isNil: Bool { self == nil }
}
