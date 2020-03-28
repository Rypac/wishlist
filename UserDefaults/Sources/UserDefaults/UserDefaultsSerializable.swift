import Foundation

public protocol UserDefaultsSerializable {
  init?(from userDefaults: UserDefaults, key: String)
  func write(to userDefaults: UserDefaults, key: String)
  func register(in userDefaults: UserDefaults, key: String)
}

extension Bool: UserDefaultsSerializable {
  public init?(from userDefaults: UserDefaults, key: String) {
    guard userDefaults.object(forKey: key) != nil else {
      return nil
    }
    self = userDefaults.bool(forKey: key)
  }

  public func write(to userDefaults: UserDefaults, key: String) {
    userDefaults.set(self, forKey: key)
  }

  public func register(in userDefaults: UserDefaults, key: String) {
    userDefaults.register(defaults: [key: self])
  }
}

extension Int: UserDefaultsSerializable {
  public init?(from userDefaults: UserDefaults, key: String) {
    guard userDefaults.object(forKey: key) != nil else {
      return nil
    }
    self = userDefaults.integer(forKey: key)
  }

  public func write(to userDefaults: UserDefaults, key: String) {
    userDefaults.set(self, forKey: key)
  }

  public func register(in userDefaults: UserDefaults, key: String) {
    userDefaults.register(defaults: [key: self])
  }
}

extension String: UserDefaultsSerializable {
  public init?(from userDefaults: UserDefaults, key: String) {
    guard let value = userDefaults.string(forKey: key) else {
      return nil
    }
    self = value
  }

  public func write(to userDefaults: UserDefaults, key: String) {
    userDefaults.set(self, forKey: key)
  }

  public func register(in userDefaults: UserDefaults, key: String) {
    userDefaults.register(defaults: [key: self])
  }
}

extension Double: UserDefaultsSerializable {
  public init?(from userDefaults: UserDefaults, key: String) {
    guard userDefaults.object(forKey: key) != nil else {
      return nil
    }
    self = userDefaults.double(forKey: key)
  }

  public func write(to userDefaults: UserDefaults, key: String) {
    userDefaults.set(self, forKey: key)
  }

  public func register(in userDefaults: UserDefaults, key: String) {
    userDefaults.register(defaults: [key: self])
  }
}

extension Float: UserDefaultsSerializable {
  public init?(from userDefaults: UserDefaults, key: String) {
    guard userDefaults.object(forKey: key) != nil else {
      return nil
    }
    self = userDefaults.float(forKey: key)
  }

  public func write(to userDefaults: UserDefaults, key: String) {
    userDefaults.set(self, forKey: key)
  }

  public func register(in userDefaults: UserDefaults, key: String) {
    userDefaults.register(defaults: [key: self])
  }
}

extension URL: UserDefaultsSerializable {
  public init?(from userDefaults: UserDefaults, key: String) {
    guard let value = userDefaults.url(forKey: key) else {
      return nil
    }
    self = value
  }

  public func write(to userDefaults: UserDefaults, key: String) {
    userDefaults.set(self, forKey: key)
  }

  public func register(in userDefaults: UserDefaults, key: String) {
    userDefaults.register(defaults: [key: self])
  }
}

extension Data: UserDefaultsSerializable {
  public init?(from userDefaults: UserDefaults, key: String) {
    guard let value = userDefaults.data(forKey: key) else {
      return nil
    }
    self = value
  }

  public func write(to userDefaults: UserDefaults, key: String) {
    userDefaults.set(self, forKey: key)
  }

  public func register(in userDefaults: UserDefaults, key: String) {
    userDefaults.register(defaults: [key: self])
  }
}

extension Date: UserDefaultsSerializable {
  public init?(from userDefaults: UserDefaults, key: String) {
    guard let value = userDefaults.object(forKey: key) as? Self else {
      return nil
    }
    self = value
  }

  public func write(to userDefaults: UserDefaults, key: String) {
    userDefaults.set(self, forKey: key)
  }

  public func register(in userDefaults: UserDefaults, key: String) {
    userDefaults.register(defaults: [key: self])
  }
}

extension Array: UserDefaultsSerializable where Element: UserDefaultsSerializable {
  public init?(from userDefaults: UserDefaults, key: String) {
    guard let value = userDefaults.array(forKey: key) as? Self else {
      return nil
    }
    self = value
  }

  public func write(to userDefaults: UserDefaults, key: String) {
    userDefaults.set(self, forKey: key)
  }

  public func register(in userDefaults: UserDefaults, key: String) {
    userDefaults.register(defaults: [key: self])
  }
}

extension Array where Element == String {
  public init?(from userDefaults: UserDefaults, key: String) {
    guard let value = userDefaults.stringArray(forKey: key) else {
      return nil
    }
    self = value
  }
}

extension Dictionary: UserDefaultsSerializable where Key == String, Value: UserDefaultsSerializable {
  public init?(from userDefaults: UserDefaults, key: String) {
    guard let value = userDefaults.dictionary(forKey: key) as? Self else {
      return nil
    }
    self = value
  }

  public func write(to userDefaults: UserDefaults, key: String) {
    userDefaults.set(self, forKey: key)
  }

  public func register(in userDefaults: UserDefaults, key: String) {
    userDefaults.register(defaults: [key: self])
  }
}

extension Optional: UserDefaultsSerializable where Wrapped: UserDefaultsSerializable {
  public init?(from userDefaults: UserDefaults, key: String) {
    guard userDefaults.object(forKey: key) != nil else {
      return nil
    }
    self = Wrapped(from: userDefaults, key: key)
  }

  public func write(to userDefaults: UserDefaults, key: String) {
    if let value = self {
      value.write(to: userDefaults, key: key)
    } else {
      userDefaults.set(nil, forKey: key)
    }
  }

  public func register(in userDefaults: UserDefaults, key: String) {
    if let value = self {
      userDefaults.register(defaults: [key: value])
    }
  }
}

extension UserDefaultsSerializable where Self: RawRepresentable, RawValue: UserDefaultsSerializable {
  public init?(from userDefaults: UserDefaults, key: String) {
    guard let rawValue = RawValue(from: userDefaults, key: key) else {
      return nil
    }
    self.init(rawValue: rawValue)
  }

  public func write(to userDefaults: UserDefaults, key: String) {
    userDefaults.set(rawValue, forKey: key)
  }

  public func register(in userDefaults: UserDefaults, key: String) {
    userDefaults.register(defaults: [key: rawValue])
  }
}
