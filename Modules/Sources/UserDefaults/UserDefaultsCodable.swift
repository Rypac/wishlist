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

extension Date: UserDefaultsCodable {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard let date = userDefaults.object(forKey: key) as? Date else {
      return nil
    }

    self = date
  }

  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    userDefaults.set(self, forKey: key)
  }
}

extension Optional: UserDefaultsCodable where Wrapped: UserDefaultsCodable {
  public init(from userDefaults: UserDefaults, forKey key: String) {
    if userDefaults.object(forKey: key) != nil {
      self = Wrapped(from: userDefaults, forKey: key)
    } else {
      self = nil
    }
  }

  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    if let value = self {
      value.encode(to: userDefaults, forKey: key)
    } else {
      userDefaults.removeObject(forKey: key)
    }
  }
}

extension Array: UserDefaultsCodable where Element: UserDefaultsConvertible {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard let array = userDefaults.array(forKey: key) else {
      return nil
    }

    if Element.self is UserDefaultsPrimitive.Type {
      self = array as! [Element]
    } else {
      self = array.compactMap { Element(storedValue: $0 as! Element.StoredValue) }
    }
  }

  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    if Element.self is UserDefaultsPrimitive.Type {
      userDefaults.set(self, forKey: key)
    } else {
      userDefaults.set(map(\.storedValue), forKey: key)
    }
  }
}

extension Set: UserDefaultsCodable where Element: UserDefaultsConvertible {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard let array = userDefaults.array(forKey: key) else {
      return nil
    }

    if Element.self is UserDefaultsPrimitive.Type {
      self = Set(array as! [Element])
    } else {
      self = array.reduce(into: Set(minimumCapacity: array.count)) { result, storedValue in
        if let element = Element(storedValue: storedValue as! Element.StoredValue) {
          result.insert(element)
        }
      }
    }
  }

  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    if Element.self is UserDefaultsPrimitive.Type {
      userDefaults.set(Array(self), forKey: key)
    } else {
      userDefaults.set(map(\.storedValue), forKey: key)
    }
  }
}

extension Dictionary: UserDefaultsCodable where Key == String, Value: UserDefaultsConvertible {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard let dictionary = userDefaults.dictionary(forKey: key) else {
      return nil
    }

    if Value.self is UserDefaultsPrimitive.Type {
      self = dictionary as! [Key: Value]
    } else {
      self = dictionary.compactMapValues { Value(storedValue: $0 as! Value.StoredValue) }
    }
  }

  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    if Value.self is UserDefaultsPrimitive.Type {
      userDefaults.set(self, forKey: key)
    } else {
      userDefaults.set(mapValues(\.storedValue), forKey: key)
    }
  }
}

extension UserDefaultsDecodable where Self: RawRepresentable, RawValue: UserDefaultsDecodable {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard let rawValue = RawValue(from: userDefaults, forKey: key) else {
      return nil
    }

    self.init(rawValue: rawValue)
  }
}

extension UserDefaultsEncodable where Self: RawRepresentable, RawValue: UserDefaultsEncodable {
  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    rawValue.encode(to: userDefaults, forKey: key)
  }
}
