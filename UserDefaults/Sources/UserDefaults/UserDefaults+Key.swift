import Foundation

public extension UserDefaults {
  struct Key<Value> {
    public let key: String
    public let defaultValue: Value
  }

  func has<Value>(_ key: Key<Value>) -> Bool {
    object(forKey: key.key) != nil
  }

  func remove<Value>(_ key: Key<Value>) {
    removeObject(forKey: key.key)
  }

  func register<Value>(_ keys: Key<Value>...) {
    register(keys)
  }

  func register<S, Value>(_ keys: S) where S: Sequence, S.Element == Key<Value> {
    register(defaults: keys.reduce(into: [:]) { defaults, key in
      defaults[key.key] = key.defaultValue
    })
  }

  subscript<Value: UserDefaultsSerializable>(key: Key<Value>) -> Value {
    get { Value(from: self, key: key.key) ?? key.defaultValue }
    set { newValue.write(to: self, key: key.key) }
  }
}

public extension UserDefaults.Key {
  init<T>(key: String) where Value == T? {
    self.init(key: key, defaultValue: nil)
  }
}
