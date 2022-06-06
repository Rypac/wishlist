import Foundation

public protocol UserDefaultsConvertible {
  associatedtype StoredValue: PropertyListValue

  var storedValue: StoredValue { get }

  init?(storedValue: StoredValue)
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

extension UserDefaultsConvertible where Self: RawRepresentable, RawValue: UserDefaultsConvertible {
  public var storedValue: RawValue { rawValue }

  public init?(storedValue: RawValue) {
    self.init(rawValue: storedValue)
  }
}

extension Array: UserDefaultsConvertible where Element: UserDefaultsConvertible {
  public typealias StoredValue = [Element.StoredValue]

  public var storedValue: StoredValue {
    map(\.storedValue)
  }

  public init(storedValue: StoredValue) {
    self = storedValue.compactMap(Element.init(storedValue:))
  }
}

extension Set: UserDefaultsConvertible where Element: UserDefaultsConvertible {
  public typealias StoredValue = [Element.StoredValue]

  public var storedValue: StoredValue {
    map(\.storedValue)
  }

  public init(storedValue: StoredValue) {
    self = storedValue.reduce(into: Set(minimumCapacity: storedValue.count)) { result, value in
      if let element = Element(storedValue: value) {
        result.insert(element)
      }
    }
  }
}

extension Dictionary: UserDefaultsConvertible where Key == String, Value: UserDefaultsConvertible {
  public typealias StoredValue = [Key: Value.StoredValue]

  public var storedValue: StoredValue {
    mapValues(\.storedValue)
  }

  public init(storedValue: StoredValue) {
    self = storedValue.compactMapValues(Value.init(storedValue:))
  }
}
