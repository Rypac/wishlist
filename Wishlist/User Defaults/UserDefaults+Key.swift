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

  subscript(key: Key<String>) -> String {
    get { string(forKey: key.key) ?? key.defaultValue }
    set { set(newValue, forKey: key.key) }
  }

  subscript(key: Key<Bool>) -> Bool {
    get { has(key) ? bool(forKey: key.key) : key.defaultValue }
    set { set(newValue, forKey: key.key) }
  }

  subscript(key: Key<Int>) -> Int {
    get { has(key) ? integer(forKey: key.key) : key.defaultValue }
    set { set(newValue, forKey: key.key) }
  }

  subscript(key: Key<Double>) -> Double {
    get { has(key) ? double(forKey: key.key) : key.defaultValue }
    set { set(newValue, forKey: key.key) }
  }

  subscript(key: Key<Float>) -> Float {
    get { has(key) ? float(forKey: key.key) : key.defaultValue }
    set { set(newValue, forKey: key.key) }
  }

  subscript(key: Key<URL>) -> URL {
    get { url(forKey: key.key) ?? key.defaultValue }
    set { set(newValue, forKey: key.key) }
  }

  subscript(key: Key<Data>) -> Data {
    get { data(forKey: key.key) ?? key.defaultValue }
    set { set(newValue, forKey: key.key) }
  }

  subscript<Value: UserDefaultsSerializable>(key: Key<Value>) -> Value {
    get { Value(from: self, key: key.key) ?? key.defaultValue }
    set { newValue.write(to: self, key: key.key) }
  }

  subscript<Value: RawRepresentable>(key: Key<Value>) -> Value {
    get {
      guard let rawValue = object(forKey: key.key) as? Value.RawValue else {
        return key.defaultValue
      }
      return Value(rawValue: rawValue) ?? key.defaultValue
    }
    set { set(newValue.rawValue, forKey: key.key) }
  }

  subscript<Value: Codable>(key: Key<Value>) -> Value {
    get {
      guard let data = data(forKey: key.key), let value = try? JSONDecoder().decode(Value.self, from: data) else {
        return key.defaultValue
      }
      return value
    }
    set {
      if let data = try? JSONEncoder().encode(newValue) {
        set(data, forKey: key.key)
      }
    }
  }
}
