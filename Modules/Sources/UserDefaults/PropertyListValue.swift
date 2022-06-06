import Foundation

public protocol PropertyListValue {
  init?(from userDefaults: UserDefaults, forKey key: String)
  func encode(to userDefaults: UserDefaults, forKey key: String)
}

extension PropertyListValue {
  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    userDefaults.set(self, forKey: key)
  }
}

extension Bool: PropertyListValue {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard userDefaults.object(forKey: key) != nil else {
      return nil
    }

    self = userDefaults.bool(forKey: key)
  }

  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    userDefaults.set(self, forKey: key)
  }
}

extension Int: PropertyListValue {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard userDefaults.object(forKey: key) != nil else {
      return nil
    }

    self = userDefaults.integer(forKey: key)
  }

  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    userDefaults.set(self, forKey: key)
  }
}

extension Float: PropertyListValue {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard userDefaults.object(forKey: key) != nil else {
      return nil
    }

    self = userDefaults.float(forKey: key)
  }

  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    userDefaults.set(self, forKey: key)
  }
}

extension Double: PropertyListValue {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard userDefaults.object(forKey: key) != nil else {
      return nil
    }

    self = userDefaults.double(forKey: key)
  }

  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    userDefaults.set(self, forKey: key)
  }
}

extension String: PropertyListValue {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard let string = userDefaults.string(forKey: key) else {
      return nil
    }

    self = string
  }
}

extension Data: PropertyListValue {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard let data = userDefaults.data(forKey: key) else {
      return nil
    }

    self = data
  }
}

extension Date: PropertyListValue {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard let date = userDefaults.object(forKey: key) as? Date else {
      return nil
    }

    self = date
  }
}

extension Array: PropertyListValue where Element: PropertyListValue {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard let array = userDefaults.array(forKey: key) else {
      return nil
    }

    self = array as! [Element]
  }
}

extension Dictionary: PropertyListValue where Key == String, Value: PropertyListValue {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard let dictionary = userDefaults.dictionary(forKey: key) else {
      return nil
    }

    self = dictionary as! [String: Value]
  }
}
