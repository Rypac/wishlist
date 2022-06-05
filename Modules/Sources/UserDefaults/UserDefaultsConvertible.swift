import Foundation

public protocol UserDefaultsConvertible: UserDefaultsCodable {
  associatedtype StoredValue

  var storedValue: StoredValue { get }

  init?(storedValue: StoredValue)
}

extension UserDefaultsConvertible where StoredValue: UserDefaultsCodable {
  public init?(from userDefaults: UserDefaults, forKey key: String) {
    guard let storedValue = StoredValue(from: userDefaults, forKey: key) else {
      return nil
    }

    self.init(storedValue: storedValue)
  }

  public func encode(to userDefaults: UserDefaults, forKey key: String) {
    storedValue.encode(to: userDefaults, forKey: key)
  }
}

extension Bool: UserDefaultsConvertible {
  public var storedValue: Bool { self }

  public init(storedValue: Bool) {
    self = storedValue
  }
}

extension Int: UserDefaultsConvertible {
  public var storedValue: Int { self }

  public init(storedValue: Int) {
    self = storedValue
  }
}

extension Float: UserDefaultsConvertible {
  public var storedValue: Float { self }

  public init(storedValue: Float) {
    self = storedValue
  }
}

extension Double: UserDefaultsConvertible {
  public var storedValue: Double { self }

  public init(storedValue: Double) {
    self = storedValue
  }
}

extension String: UserDefaultsConvertible {
  public var storedValue: String { self }

  public init(storedValue: String) {
    self = storedValue
  }
}

extension URL: UserDefaultsConvertible {
  public var storedValue: String { absoluteString }

  public init?(storedValue: String) {
    self.init(string: storedValue)
  }
}

extension UUID: UserDefaultsConvertible {
  public var storedValue: String { uuidString }

  public init?(storedValue: String) {
    self.init(uuidString: storedValue)
  }
}

extension Data: UserDefaultsConvertible {
  public var storedValue: Data { self }

  public init(storedValue: Data) {
    self = storedValue
  }
}

extension Date: UserDefaultsConvertible {
  public var storedValue: Date { self }

  public init(storedValue: Date) {
    self = storedValue
  }
}

extension Optional: UserDefaultsConvertible where Wrapped: UserDefaultsConvertible {
  public var storedValue: Wrapped.StoredValue? { self?.storedValue }

  public init(storedValue: Wrapped.StoredValue?) {
    if let storedValue = storedValue {
      self = Wrapped(storedValue: storedValue)
    } else {
      self = nil
    }
  }
}

extension UserDefaultsConvertible where Self: RawRepresentable, RawValue: UserDefaultsConvertible {
  public var storedValue: RawValue { rawValue }

  public init?(storedValue: RawValue) {
    self.init(rawValue: storedValue)
  }
}

extension Array: UserDefaultsConvertible where Element: UserDefaultsConvertible, Element.StoredValue: UserDefaultsConvertible {
  public typealias StoredValue = [Element.StoredValue]

  public var storedValue: StoredValue {
    if Element.self is UserDefaultsPrimitive.Type {
      return self as! StoredValue
    } else {
      return map(\.storedValue)
    }
  }

  public init(storedValue: StoredValue) {
    if Element.self is UserDefaultsPrimitive.Type {
      self = storedValue as! [Element]
    } else {
      self = storedValue.compactMap(Element.init(storedValue:))
    }
  }
}

extension Set: UserDefaultsConvertible where Element: UserDefaultsConvertible, Element.StoredValue: UserDefaultsConvertible {
  public typealias StoredValue = [Element.StoredValue]

  public var storedValue: StoredValue {
    if Element.self is UserDefaultsPrimitive.Type {
      return Array(self) as! StoredValue
    } else {
      return map(\.storedValue)
    }
  }

  public init(storedValue: StoredValue) {
    if Element.self is UserDefaultsPrimitive.Type {
      self = Set(storedValue as! [Element])
    } else {
      self = Set(storedValue.compactMap(Element.init(storedValue:)))
    }
  }
}

extension Dictionary: UserDefaultsConvertible where Key == String, Value: UserDefaultsConvertible, Value.StoredValue: UserDefaultsConvertible {
  public typealias StoredValue = [Key: Value.StoredValue]

  public var storedValue: StoredValue {
    if Value.self is UserDefaultsPrimitive.Type {
      return self as! StoredValue
    } else {
      return mapValues(\.storedValue)
    }
  }

  public init(storedValue: StoredValue) {
    if Value.self is UserDefaultsPrimitive.Type {
      self = storedValue as! [Key: Value]
    } else {
      self = storedValue.compactMapValues(Value.init(storedValue:))
    }
  }
}
