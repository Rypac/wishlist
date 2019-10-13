import Foundation

public extension UserDefaults {
  struct Key<Value> {
    public let key: String
    public let defaultValue: Value
  }

  func has<Value>(_ key: Key<Value>) -> Bool {
    object(forKey: key.key) != nil
  }

  func register<Value>(_ key: Key<Value>) {
    register(defaults: [key.key: key.defaultValue])
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
