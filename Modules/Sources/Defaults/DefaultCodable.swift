import Foundation

public protocol DefaultsDecodable {
  init?(from decoder: UserDefaultsDecoder)
}

public protocol DefaultsEncodable {
  func encode(to encoder: UserDefaultsEncoder)
}

public typealias DefaultsCodable = DefaultsDecodable & DefaultsEncodable

public struct UserDefaultsDecoder {
  private let key: String
  private let userDefaults: UserDefaults

  init(key: String, userDefaults: UserDefaults) {
    self.key = key
    self.userDefaults = userDefaults
  }

  public func decodeNil() -> Bool {
    userDefaults.object(forKey: key) == nil
  }

  public func decode(_ type: Bool.Type) -> Bool? {
    guard userDefaults.object(forKey: key) != nil else {
      return nil
    }

    return userDefaults.bool(forKey: key)
  }

  public func decode(_ type: Int.Type) -> Int? {
    guard userDefaults.object(forKey: key) != nil else {
      return nil
    }

    return userDefaults.integer(forKey: key)
  }

  public func decode(_ type: Float.Type) -> Float? {
    guard userDefaults.object(forKey: key) != nil else {
      return nil
    }

    return userDefaults.float(forKey: key)
  }

  public func decode(_ type: Double.Type) -> Double? {
    guard userDefaults.object(forKey: key) != nil else {
      return nil
    }

    return userDefaults.double(forKey: key)
  }

  public func decode(_ type: String.Type) -> String? {
    userDefaults.string(forKey: key)
  }

  public func decode(_ type: URL.Type) -> URL? {
    userDefaults.url(forKey: key)
  }

  public func decode(_ type: Data.Type) -> Data? {
    userDefaults.data(forKey: key)
  }

  public func decode<Value: DefaultsDecodable>(_ type: Value.Type) -> Value? {
    Value(from: self)
  }
}

public class UserDefaultsEncoder {
  private let key: String
  private let userDefaults: UserDefaults

  init(key: String, userDefaults: UserDefaults) {
    self.key = key
    self.userDefaults = userDefaults
  }

  public func encodeNil() {
    userDefaults.removeObject(forKey: key)
  }

  public func encode(_ value: Bool) {
    userDefaults.set(value, forKey: key)
  }

  public func encode(_ value: String) {
    userDefaults.set(value, forKey: key)
  }

  public func encode(_ value: Double) {
    userDefaults.set(value, forKey: key)
  }

  public func encode(_ value: Float) {
    userDefaults.set(value, forKey: key)
  }

  public func encode(_ value: Int) {
    userDefaults.set(value, forKey: key)
  }

  public func encode(_ value: Data) {
    userDefaults.set(value, forKey: key)
  }

  public func encode<Value: DefaultsEncodable>(_ value: Value) {
    value.encode(to: self)
  }
}

extension Bool: DefaultsCodable {
  public init?(from decoder: UserDefaultsDecoder) {
    guard let bool = decoder.decode(Bool.self) else {
      return nil
    }

    self = bool
  }

  public func encode(to encoder: UserDefaultsEncoder) {
    encoder.encode(self)
  }
}

extension Int: DefaultsCodable {
  public init?(from decoder: UserDefaultsDecoder) {
    guard let int = decoder.decode(Int.self) else {
      return nil
    }

    self = int
  }

  public func encode(to encoder: UserDefaultsEncoder) {
    encoder.encode(self)
  }
}

extension Float: DefaultsCodable {
  public init?(from decoder: UserDefaultsDecoder) {
    guard let float = decoder.decode(Float.self) else {
      return nil
    }

    self = float
  }

  public func encode(to encoder: UserDefaultsEncoder) {
    encoder.encode(self)
  }
}

extension Double: DefaultsCodable {
  public init?(from decoder: UserDefaultsDecoder) {
    guard let double = decoder.decode(Double.self) else {
      return nil
    }

    self = double
  }

  public func encode(to encoder: UserDefaultsEncoder) {
    encoder.encode(self)
  }
}

extension String: DefaultsCodable {
  public init?(from decoder: UserDefaultsDecoder) {
    guard let string = decoder.decode(String.self) else {
      return nil
    }

    self = string
  }

  public func encode(to encoder: UserDefaultsEncoder) {
    encoder.encode(self)
  }
}

extension Data: DefaultsCodable {
  public init?(from decoder: UserDefaultsDecoder) {
    guard let data = decoder.decode(Data.self) else {
      return nil
    }

    self = data
  }

  public func encode(to encoder: UserDefaultsEncoder) {
    encoder.encode(self)
  }
}

extension Optional: DefaultsCodable where Wrapped: DefaultsCodable {
  public init?(from decoder: UserDefaultsDecoder) {
    if decoder.decodeNil() {
      return nil
    } else {
      self = decoder.decode(Wrapped.self)
    }
  }

  public func encode(to encoder: UserDefaultsEncoder) {
    if let wrapped = self {
      encoder.encode(wrapped)
    } else {
      encoder.encodeNil()
    }
  }
}

extension DefaultsDecodable where Self: RawRepresentable, RawValue: DefaultsDecodable {
  public init?(from decoder: UserDefaultsDecoder) {
    guard let rawValue = decoder.decode(RawValue.self) else {
      return nil
    }

    self.init(rawValue: rawValue)
  }
}

extension DefaultsEncodable where Self: RawRepresentable, RawValue: DefaultsEncodable {
  public func encode(to encoder: UserDefaultsEncoder) {
    encoder.encode(rawValue)
  }
}
