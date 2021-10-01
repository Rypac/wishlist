import Foundation

public protocol UserDefaultsDecodable {
  init?(from userDefaults: UserDefaults, forKey key: String)
}

public protocol UserDefaultsEncodable {
  func encode(to userDefaults: UserDefaults, forKey key: String)
}

public typealias UserDefaultsCodable = UserDefaultsDecodable & UserDefaultsEncodable

extension Bool: UserDefaultsCodable {
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

extension Int: UserDefaultsCodable {
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

extension Float: UserDefaultsCodable {
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

extension Double: UserDefaultsCodable {
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

extension String: UserDefaultsCodable {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard let string = userDefaults.string(forKey: key) else {
      return nil
    }

    self = string
  }

  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    userDefaults.set(self, forKey: key)
  }
}

extension URL: UserDefaultsCodable {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard let url = userDefaults.url(forKey: key) else {
      return nil
    }

    self = url
  }

  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    userDefaults.set(self, forKey: key)
  }
}

extension Data: UserDefaultsCodable {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard let data = userDefaults.data(forKey: key) else {
      return nil
    }

    self = data
  }

  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    userDefaults.set(self, forKey: key)
  }
}

extension Optional: UserDefaultsCodable where Wrapped: UserDefaultsCodable {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard userDefaults.object(forKey: key) != nil else {
      return nil
    }

    self = Wrapped.init(from: userDefaults, forKey: key)
  }

  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    if let value = self {
      value.encode(to: userDefaults, forKey: key)
    } else {
      userDefaults.removeObject(forKey: key)
    }
  }
}

extension Array: UserDefaultsCodable where Element: UserDefaultsSerializable {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard let array = userDefaults.array(forKey: key) else {
      return nil
    }

    if Self.Element.self is UserDefaultsPrimitive.Type {
      self = array as! [Element]
    } else {
      self = array.compactMap { Element(storedValue: ($0 as! Element).storedValue) }
    }
  }

  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    if Self.Element.self is UserDefaultsPrimitive.Type {
      userDefaults.set(self, forKey: key)
    } else {
      userDefaults.set(map(\.storedValue), forKey: key)
    }
  }
}

extension Set: UserDefaultsCodable where Element: UserDefaultsSerializable {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard let array = userDefaults.array(forKey: key) else {
      return nil
    }

    if Self.Element.self is UserDefaultsPrimitive.Type {
      self = Set(array as! [Element])
    } else {
      self = Set(array.compactMap { Element(storedValue: ($0 as! Element).storedValue) })
    }
  }

  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    if Self.Element.self is UserDefaultsPrimitive.Type {
      userDefaults.set(Array(self), forKey: key)
    } else {
      userDefaults.set(map(\.storedValue), forKey: key)
    }
  }
}
