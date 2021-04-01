import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public typealias SQLiteStatement = OpaquePointer

// MARK: Decoder

public protocol SQLiteDecodable {
  init(from decoder: SQLiteDecoder) throws
}

public protocol SQLiteDecoder {
  mutating func decodeNil() throws -> Bool
  mutating func decode(_ type: Bool.Type) throws -> Bool
  mutating func decode(_ type: Int.Type) throws -> Int
  mutating func decode(_ type: Double.Type) throws -> Double
  mutating func decode(_ type: Float.Type) throws -> Float
  mutating func decode(_ type: String.Type) throws -> String
  mutating func decode(_ type: Data.Type) throws -> Data
  mutating func decode<T>(_ type: T.Type) throws -> T where T: SQLiteDecodable
}

extension SQLiteDecoder {
  public mutating func decodeIfPresent(_ type: Bool.Type) throws -> Bool? {
    try decodeNil() ? nil : try decode(type)
  }

  public mutating func decodeIfPresent(_ type: Int.Type) throws -> Int? {
    try decodeNil() ? nil : try decode(type)
  }

  public mutating func decodeIfPresent(_ type: Double.Type) throws -> Double? {
    try decodeNil() ? nil : try decode(type)
  }

  public mutating func decodeIfPresent(_ type: Float.Type) throws -> Float? {
    try decodeNil() ? nil : try decode(type)
  }

  public mutating func decodeIfPresent(_ type: String.Type) throws -> String? {
    try decodeNil() ? nil : try decode(type)
  }

  public mutating func decodeIfPresent(_ type: Data.Type) throws -> Data? {
    try decodeNil() ? nil : try decode(type)
  }

  public mutating func decodeIfPresent<T>(_ type: T.Type) throws -> T? where T: SQLiteDecodable {
    try decodeNil() ? nil : try decode(type)
  }
}

enum SQLiteDecodingError: Error {
  case typeMismatch(Any.Type, description: String)
  case dataCorrupted(description: String)
  case exceededColumnCount(index: Int)
}

extension Bool: SQLiteDecodable {
  public init(from decoder: SQLiteDecoder) throws {
    var decoder = decoder
    self = try decoder.decode(Bool.self)
  }
}

extension Int: SQLiteDecodable {
  public init(from decoder: SQLiteDecoder) throws {
    var decoder = decoder
    self = try decoder.decode(Int.self)
  }
}

extension Double: SQLiteDecodable {
  public init(from decoder: SQLiteDecoder) throws {
    var decoder = decoder
    self = try decoder.decode(Double.self)
  }
}

extension Float: SQLiteDecodable {
  public init(from decoder: SQLiteDecoder) throws {
    var decoder = decoder
    self = try decoder.decode(Float.self)
  }
}

extension String: SQLiteDecodable {
  public init(from decoder: SQLiteDecoder) throws {
    var decoder = decoder
    self = try decoder.decode(String.self)
  }
}

extension URL: SQLiteDecodable {
  public init(from decoder: SQLiteDecoder) throws {
    var decoder = decoder
    let absoluteString = try decoder.decode(String.self)
    guard let url = URL(string: absoluteString) else {
      throw SQLiteDecodingError.dataCorrupted(description: "Invalid URL: \(absoluteString)")
    }

    self = url
  }
}

extension Date: SQLiteDecodable {
  public init(from decoder: SQLiteDecoder) throws {
    var decoder = decoder
    let timestamp = try decoder.decode(String.self)
    guard let date = utcISO8601DateFormatter.date(from: timestamp) else {
      throw SQLiteDecodingError.dataCorrupted(description: "Invalid ISO-8601 date: \(timestamp)")
    }

    self = date
  }
}

extension Optional: SQLiteDecodable where Wrapped: SQLiteDecodable {
  public init(from decoder: SQLiteDecoder) throws {
    var decoder = decoder
    if try decoder.decodeNil() {
      self = nil
    } else {
      self = try decoder.decode(Wrapped.self)
    }
  }
}

extension SQLiteDecodable where Self: RawRepresentable, RawValue: SQLiteDecodable {
  public init(from decoder: SQLiteDecoder) throws {
    var decoder = decoder
    guard let value = Self.init(rawValue: try decoder.decode(RawValue.self)) else {
      throw SQLiteDecodingError.dataCorrupted(description: "Invalid raw value")
    }
    self = value
  }
}

struct SQLiteRowDecoder: SQLiteDecoder {
  private var statement: SQLiteStatement?
  private var index: Int32 = 0

  init(statement: SQLiteStatement?) {
    self.statement = statement
  }

  private func checkIndex() throws {
    guard index < sqlite3_column_count(statement) else {
      throw SQLiteDecodingError.exceededColumnCount(index: Int(index))
    }
  }

  mutating func decodeNil() throws -> Bool {
    try checkIndex()
    let isNil = sqlite3_column_type(statement, index) == SQLITE_NULL
    if isNil {
      index += 1
    }
    return isNil
  }

  mutating func decode(_ type: Bool.Type) throws -> Bool {
    try checkIndex()
    defer { index += 1 }
    switch sqlite3_column_type(statement, index) {
    case SQLITE_INTEGER:
      return sqlite3_column_int64(statement, index) != 0
    case SQLITE_FLOAT:
      return sqlite3_column_double(statement, index) != 0.0
    default:
      throw SQLiteDecodingError.typeMismatch(Bool.self, description: "Expected INTEGER or REAL")
    }
  }

  mutating func decode(_ type: Int.Type) throws -> Int {
    try checkIndex()
    defer { index += 1 }
    switch sqlite3_column_type(statement, index) {
    case SQLITE_INTEGER:
      return Int(sqlite3_column_int64(statement, index))
    default:
      throw SQLiteDecodingError.typeMismatch(Int.self, description: "Expected INTEGER")
    }
  }

  mutating func decode(_ type: Double.Type) throws -> Double {
    try checkIndex()
    defer { index += 1 }
    switch sqlite3_column_type(statement, index) {
    case SQLITE_FLOAT:
      return sqlite3_column_double(statement, index)
    default:
      throw SQLiteDecodingError.typeMismatch(Double.self, description: "Expected REAL")
    }
  }

  mutating func decode(_ type: Float.Type) throws -> Float {
    try checkIndex()
    defer { index += 1 }
    switch sqlite3_column_type(statement, index) {
    case SQLITE_FLOAT:
      return Float(sqlite3_column_double(statement, index))
    default:
      throw SQLiteDecodingError.typeMismatch(Float.self, description: "Expected REAL")
    }
  }

  mutating func decode(_ type: String.Type) throws -> String {
    try checkIndex()
    defer { index += 1 }
    switch sqlite3_column_type(statement, index) {
    case SQLITE_TEXT:
      return String(cString: sqlite3_column_text(statement, index))
    default:
      throw SQLiteDecodingError.typeMismatch(String.self, description: "Expected TEXT")
    }
  }

  mutating func decode(_ type: Data.Type) throws -> Data {
    try checkIndex()
    defer { index += 1 }
    switch sqlite3_column_type(statement, index) {
    case SQLITE_BLOB:
      return sqlite3_column_blob(statement, index).load(as: Data.self)
    default:
      throw SQLiteDecodingError.typeMismatch(Data.self, description: "Expected BLOB")
    }
  }

  mutating func decode<T>(_ type: T.Type) throws -> T where T: SQLiteDecodable {
    try checkIndex()
    defer { index += 1 }
    return try T(from: self)
  }
}

// MARK: Encoder

public protocol SQLiteEncodable {
  func encode(to encoder: SQLiteEncoder) throws
}

public protocol SQLiteEncoder {
  mutating func encodeNil() throws
  mutating func encode(_ value: Bool) throws
  mutating func encode(_ value: Int) throws
  mutating func encode(_ value: Double) throws
  mutating func encode(_ value: String) throws
  mutating func encode(_ value: Data) throws
  mutating func encode(_ value: SQLiteEncodable) throws
}

final class SQLiteBindingEncoder: SQLiteEncoder {
  private var statement: SQLiteStatement?
  private var index: Int32 = 1

  init(statement: SQLiteStatement?) {
    self.statement = statement
  }

  public func encodeNil() throws {
    defer { index += 1 }
    let result = sqlite3_bind_null(statement, index)
    guard result == SQLITE_OK else {
      throw SQLiteEncodingError.invalid(code: result)
    }
  }

  public func encode(_ value: Bool) throws {
    defer { index += 1 }
    let result = sqlite3_bind_int64(statement, index, value ? 1 : 0)
    guard result == SQLITE_OK else {
      throw SQLiteEncodingError.invalid(code: result)
    }
  }

  public func encode(_ value: Int) throws {
    defer { index += 1 }
    let result = sqlite3_bind_int64(statement, index, Int64(value))
    guard result == SQLITE_OK else {
      throw SQLiteEncodingError.invalid(code: result)
    }
  }

  public func encode(_ value: Double) throws {
    defer { index += 1 }
    let result = sqlite3_bind_double(statement, index, value)
    guard result == SQLITE_OK else {
      throw SQLiteEncodingError.invalid(code: result)
    }
  }

  public func encode(_ value: String) throws {
    defer { index += 1 }
    let result = sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
    guard result == SQLITE_OK else {
      throw SQLiteEncodingError.invalid(code: result)
    }
  }

  public func encode(_ value: Data) throws {
    defer { index += 1 }
    try value.withUnsafeBytes { bytes in
      let result = sqlite3_bind_blob(statement, index, bytes.baseAddress, -1, SQLITE_TRANSIENT)
      guard result == SQLITE_OK else {
        throw SQLiteEncodingError.invalid(code: result)
      }
    }
  }

  public func encode(_ value: SQLiteEncodable) throws {
    defer { index += 1 }
    try value.encode(to: self)
  }
}

public enum SQLiteEncodingError: Error {
  case invalid(code: Int32)
}

extension Bool: SQLiteEncodable {
  public func encode(to encoder: SQLiteEncoder) throws {
    var encoder = encoder
    try encoder.encode(self)
  }
}

extension Int: SQLiteEncodable {
  public func encode(to encoder: SQLiteEncoder) throws {
    var encoder = encoder
    try encoder.encode(self)
  }
}

extension Double: SQLiteEncodable {
  public func encode(to encoder: SQLiteEncoder) throws {
    var encoder = encoder
    try encoder.encode(self)
  }
}

extension Float: SQLiteEncodable {
  public func encode(to encoder: SQLiteEncoder) throws {
    var encoder = encoder
    try encoder.encode(Double(self))
  }
}

extension String: SQLiteEncodable {
  public func encode(to encoder: SQLiteEncoder) throws {
    var encoder = encoder
    try encoder.encode(self)
  }
}

extension Date: SQLiteEncodable {
  public func encode(to encoder: SQLiteEncoder) throws {
    var encoder = encoder
    try encoder.encode(utcISO8601DateFormatter.string(from: self))
  }
}

extension URL: SQLiteEncodable {
  public func encode(to encoder: SQLiteEncoder) throws {
    var encoder = encoder
    try encoder.encode(absoluteString)
  }
}

extension Optional: SQLiteEncodable where Wrapped: SQLiteEncodable {
  public func encode(to encoder: SQLiteEncoder) throws {
    var encoder = encoder
    if let value = self {
      try encoder.encode(value)
    } else {
      try encoder.encodeNil()
    }
  }
}

extension SQLiteEncodable where Self: RawRepresentable, RawValue: SQLiteEncodable {
  public func encode(to encoder: SQLiteEncoder) throws {
    var encoder = encoder
    try encoder.encode(rawValue)
  }
}

private let utcISO8601DateFormatter = ISO8601DateFormatter()
