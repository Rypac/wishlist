import Foundation

public protocol UserDefaultsSerializable {
  init?(from userDefaults: UserDefaults, key: String)
  func write(to userDefaults: UserDefaults, key: String)
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
}

extension UserDefaultsSerializable where Self: Codable {
  public init?(from userDefaults: UserDefaults, key: String) {
    guard let data = userDefaults.data(forKey: key), let value = try? JSONDecoder().decode(Self.self, from: data) else {
      return nil
    }
    self = value
  }

  public func write(to userDefaults: UserDefaults, key: String) {
    if let data = try? JSONEncoder().encode(self) {
      userDefaults.set(data, forKey: key)
    }
  }
}
