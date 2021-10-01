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

  public func register<Value: UserDefaultsSerializable>(_ keys: UserDefaultsKey<Value>...) {
    register(defaults: keys.reduce(into: Dictionary(minimumCapacity: keys.count)) { defaults, key in
      if let optionalValue = key.defaultValue as? AnyOptional, optionalValue.isNil {
        return
      }

      defaults[key.key] = key.defaultValue.storedValue
    })
  }

  public subscript<Value: UserDefaultsSerializable>(key: String) -> Value? {
    get {
      guard let storedValue = Value.StoredValue(from: self, forKey: key) else {
        return nil
      }

      return Value(storedValue: storedValue)
    }
    set {
      if let value = newValue {
        value.storedValue.encode(to: self, forKey: key)
      } else {
        removeObject(forKey: key)
      }
    }
  }

  public subscript<Value: UserDefaultsSerializable>(key: UserDefaultsKey<Value>) -> Value {
    get {
      guard
        let storedValue = Value.StoredValue(from: self, forKey: key.key),
        let value = Value(storedValue: storedValue)
      else {
        return key.defaultValue
      }

      return value
    }
    set { newValue.storedValue.encode(to: self, forKey: key.key) }
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
