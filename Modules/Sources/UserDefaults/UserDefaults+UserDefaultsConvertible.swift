import Foundation

extension UserDefaults {
  public func register<Value: UserDefaultsConvertible>(_ value: Value, forKey key: String) {
    register(defaults: [key: value.storedValue])
  }

  public subscript<Value: UserDefaultsConvertible>(key: String) -> Value? {
    get {
      let fetched: Any?

      if let decodableType = Value.StoredValue.self as? UserDefaultsDecodable.Type {
        fetched = decodableType.init(from: self, forKey: key)
      } else {
        fetched = object(forKey: key)
      }

      guard let fetched = fetched else {
        return nil
      }

      return Value(storedValue: fetched as! Value.StoredValue)
    }
    set {
      guard let storedValue = newValue?.storedValue else {
        removeObject(forKey: key)
        return
      }

      if let encodableStoredValue = storedValue as? UserDefaultsEncodable {
        encodableStoredValue.encode(to: self, forKey: key)
      } else {
        set(storedValue, forKey: key)
      }
    }
  }
}
