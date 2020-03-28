import Foundation

public extension UserDefaults {
  struct Key<Value: UserDefaultsSerializable> {
    public let key: String
    public let defaultValue: Value
  }

  func has<Value>(_ key: Key<Value>) -> Bool {
    object(forKey: key.key) != nil
  }

  func remove<Value>(_ key: Key<Value>) {
    removeObject(forKey: key.key)
  }

  func register<Value>(_ key: Key<Value>) {
    key.defaultValue.register(in: self, key: key.key)
  }

  subscript<Value>(key: Key<Value>) -> Value {
    get { Value(from: self, key: key.key) ?? key.defaultValue }
    set { newValue.write(to: self, key: key.key) }
  }
}

public extension UserDefaults.Key {
  init<T>(key: String) where Value == T? {
    self.init(key: key, defaultValue: nil)
  }
}
