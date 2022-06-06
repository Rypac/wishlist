import Foundation

extension UserDefaults {
  public func register<Value: UserDefaultsConvertible>(_ value: Value, forKey key: String) {
    register(defaults: [key: value.storedValue])
  }

  public subscript<Value: UserDefaultsConvertible>(key: String) -> Value? {
    get {
      guard let storedValue = Value.StoredValue(from: self, forKey: key) else {
        return nil
      }

      return Value(storedValue: storedValue)
    }
    set {
      if let storedValue = newValue?.storedValue {
        storedValue.encode(to: self, forKey: key)
      } else {
        removeObject(forKey: key)
      }
    }
  }
}
