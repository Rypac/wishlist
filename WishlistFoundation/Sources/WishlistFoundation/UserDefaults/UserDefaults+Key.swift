import Foundation

public extension UserDefaults {
  struct Key<Value> {
    public let key: String
    public let defaultValue: Value
  }

  func has(_ key: String) -> Bool {
    object(forKey: key) != nil
  }
}

public extension UserDefaults.Key {
  init<T>(key: String) where Value == T? {
    self.init(key: key, defaultValue: nil)
  }
}
