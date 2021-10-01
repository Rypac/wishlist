import Foundation

public protocol UserDefaultsSerializable: UserDefaultsCodable {
    associatedtype StoredValue

    var storedValue: StoredValue { get }

    init?(storedValue: StoredValue)
}

extension UserDefaultsSerializable {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard let value = userDefaults.object(forKey: key) as? StoredValue else {
      return nil
    }

    self.init(storedValue: value)
  }

  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    userDefaults.set(storedValue, forKey: key)
  }
}

extension Bool: UserDefaultsSerializable {
  public var storedValue: Self { self }

  public init(storedValue: StoredValue) {
    self = storedValue
  }
}

extension Int: UserDefaultsSerializable {
  public var storedValue: Self { self }

  public init(storedValue: StoredValue) {
    self = storedValue
  }
}

extension Float: UserDefaultsSerializable {
  public var storedValue: Self { self }

  public init(storedValue: StoredValue) {
    self = storedValue
  }
}

extension Double: UserDefaultsSerializable {
  public var storedValue: Self { self }

  public init(storedValue: StoredValue) {
    self = storedValue
  }
}

extension String: UserDefaultsSerializable {
  public var storedValue: Self { self }

  public init(storedValue: StoredValue) {
    self = storedValue
  }
}

extension URL: UserDefaultsSerializable {
  public var storedValue: String { absoluteString }

  public init?(storedValue: StoredValue) {
    self.init(string: storedValue)
  }
}

extension UUID: UserDefaultsSerializable {
  public var storedValue: String { uuidString }

  public init?(storedValue: StoredValue) {
    self.init(uuidString: storedValue)
  }
}

extension Data: UserDefaultsSerializable {
  public var storedValue: Self { self }

  public init(storedValue: StoredValue) {
    self = storedValue
  }
}

extension Date: UserDefaultsSerializable {
  private static let utcISO8601DateFormatter = ISO8601DateFormatter()

  public var storedValue: String { Date.utcISO8601DateFormatter.string(from: self) }

  public init?(storedValue: StoredValue) {
    guard let date = Date.utcISO8601DateFormatter.date(from: storedValue) else {
      return nil
    }

    self = date
  }
}

extension Optional: UserDefaultsSerializable where Wrapped: UserDefaultsSerializable {
  public var storedValue: Self { self }

  public init(storedValue: StoredValue) {
    self = storedValue
  }
}

extension UserDefaultsSerializable where Self: RawRepresentable, RawValue: UserDefaultsSerializable {
  public var storedValue: RawValue { rawValue }

  public init?(storedValue: RawValue) {
    self.init(rawValue: storedValue)
  }
}

extension Array: UserDefaultsSerializable where Element: UserDefaultsSerializable {
  public typealias StoredValue = [Element.StoredValue]

  public var storedValue: StoredValue {
    if Self.Element.self is UserDefaultsPrimitive.Type {
      return self as! StoredValue
    } else {
      return map(\.storedValue)
    }
  }

  public init?(storedValue: StoredValue) {
    self = storedValue.compactMap(Element.init(storedValue:))
  }
}

extension Set: UserDefaultsSerializable where Element: UserDefaultsSerializable {
  public typealias StoredValue = [Element.StoredValue]

  public var storedValue: StoredValue {
    if Self.Element.self is UserDefaultsPrimitive.Type {
      return Array(self) as! StoredValue
    } else {
      return map(\.storedValue)
    }
  }

  public init?(storedValue: StoredValue) {
    self = Set(storedValue.compactMap(Element.init(storedValue:)))
  }
}
