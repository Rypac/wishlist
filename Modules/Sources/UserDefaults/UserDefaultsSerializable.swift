import Foundation

public protocol UserDefaultsSerializable {
  associatedtype StoredValue: UserDefaultsCodable

  var storedValue: StoredValue { get }

  init?(storedValue: StoredValue)
}

extension Bool: UserDefaultsSerializable {
  public var storedValue: Bool { self }

  public init(storedValue: Bool) {
    self = storedValue
  }
}

extension Int: UserDefaultsSerializable {
  public var storedValue: Int { self }

  public init(storedValue: Int) {
    self = storedValue
  }
}

extension Float: UserDefaultsSerializable {
  public var storedValue: Float { self }

  public init(storedValue: Float) {
    self = storedValue
  }
}

extension Double: UserDefaultsSerializable {
  public var storedValue: Double { self }

  public init(storedValue: Double) {
    self = storedValue
  }
}

extension String: UserDefaultsSerializable {
  public var storedValue: String { self }

  public init(storedValue: String) {
    self = storedValue
  }
}

extension URL: UserDefaultsSerializable {
  public var storedValue: String { absoluteString }

  public init?(storedValue: String) {
    self.init(string: storedValue)
  }
}

extension UUID: UserDefaultsSerializable {
  public var storedValue: String { uuidString }

  public init?(storedValue: String) {
    self.init(uuidString: storedValue)
  }
}

extension Data: UserDefaultsSerializable {
  public var storedValue: Data { self }

  public init(storedValue: Data) {
    self = storedValue
  }
}

extension Date: UserDefaultsSerializable {
  public var storedValue: Date { self }

  public init(storedValue: Date) {
    self = storedValue
  }
}

extension Optional: UserDefaultsSerializable where Wrapped: UserDefaultsSerializable {
  public var storedValue: Wrapped.StoredValue? { self?.storedValue }

  public init?(storedValue: Wrapped.StoredValue?) {
    guard let storedValue = storedValue else {
      return nil
    }

    self = Wrapped(storedValue: storedValue)
  }
}

extension UserDefaultsSerializable where Self: RawRepresentable, RawValue: UserDefaultsSerializable {
  public var storedValue: RawValue { rawValue }

  public init?(storedValue: RawValue) {
    self.init(rawValue: storedValue)
  }
}

extension Array: UserDefaultsSerializable where Element: UserDefaultsSerializable, Element.StoredValue: UserDefaultsSerializable {
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

extension Set: UserDefaultsSerializable where Element: UserDefaultsSerializable, Element.StoredValue: UserDefaultsSerializable {
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

extension Dictionary: UserDefaultsSerializable where Key == String, Value: UserDefaultsSerializable, Value.StoredValue: UserDefaultsSerializable {
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
