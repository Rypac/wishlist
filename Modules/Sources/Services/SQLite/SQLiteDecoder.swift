import Foundation
import SQLite3

public typealias SQLiteStatement = OpaquePointer

public struct SQLiteColumn: Equatable {
  public let rawValue: Int32

  init(rawValue: Int32) {
    self.rawValue = rawValue
  }
}

extension SQLiteColumn: CustomStringConvertible {
  public var description: String {
    switch self {
    case .null: return "NULL"
    case .integer: return "INTEGER"
    case .float: return "REAL"
    case .text: return "TEXT"
    case .blob: return "BLOB"
    default: return "UNKNOWN"
    }
  }
}

extension SQLiteColumn {
  public static let null = SQLiteColumn(rawValue: SQLITE_NULL)
  public static let integer = SQLiteColumn(rawValue: SQLITE_INTEGER)
  public static let float = SQLiteColumn(rawValue: SQLITE_FLOAT)
  public static let text = SQLiteColumn(rawValue: SQLITE3_TEXT)
  public static let blob = SQLiteColumn(rawValue: SQLITE_BLOB)
}

extension SQLiteColumn: ExpressibleByNilLiteral {
  public init(nilLiteral: ()) {
    self = .null
  }
}

// MARK: Decoder

public protocol SQLiteRowDecodable {
  init(from decoder: SQLiteDecoder) throws
}

public protocol SQLiteColumnDecodable {
  init(statement: SQLiteStatement?, index: Int32) throws
}

extension SQLiteRowDecodable where Self: SQLiteColumnDecodable {
  init(from decoder: SQLiteDecoder) throws {
    var decoder = decoder
    self = try decoder.decode(Self.self)
  }
}

enum SQLiteDecodingError: Error {
  case typeMismatch(Any.Type, description: String)
  case dataCorrupted(description: String)
}

extension Bool: SQLiteColumnDecodable {
  public init(statement: SQLiteStatement?, index: Int32) throws {
    switch SQLiteColumn(rawValue: sqlite3_column_type(statement, index)) {
    case .integer:
      self = sqlite3_column_int64(statement, index) != 0
    case .float:
      self = sqlite3_column_double(statement, index) != 0.0
    case let column:
      throw SQLiteDecodingError.typeMismatch(
        Bool.self,
        description: "Expected \(SQLiteColumn.integer) or \(SQLiteColumn.float) but was \(column)"
      )
    }
  }
}

extension Int: SQLiteColumnDecodable {
  public init(statement: SQLiteStatement?, index: Int32) throws {
    switch SQLiteColumn(rawValue: sqlite3_column_type(statement, index)) {
    case .integer:
      self = Int(sqlite3_column_int64(statement, index))
    case let column:
      throw SQLiteDecodingError.typeMismatch(
        Int.self,
        description: "Expected \(SQLiteColumn.integer) but was \(column)"
      )
    }
  }
}

extension Double: SQLiteColumnDecodable {
  public init(statement: SQLiteStatement?, index: Int32) throws {
    switch SQLiteColumn(rawValue: sqlite3_column_type(statement, index)) {
    case .float:
      self = sqlite3_column_double(statement, index)
    case let column:
      throw SQLiteDecodingError.typeMismatch(
        Double.self,
        description: "Expected \(SQLiteColumn.float) but was \(column)"
      )
    }
  }
}

extension Float: SQLiteColumnDecodable {
  public init(statement: SQLiteStatement?, index: Int32) throws {
    switch SQLiteColumn(rawValue: sqlite3_column_type(statement, index)) {
    case .float:
      self = Float(sqlite3_column_double(statement, index))
    case let column:
      throw SQLiteDecodingError.typeMismatch(
        Float.self,
        description: "Expected \(SQLiteColumn.float) but was \(column)"
      )
    }
  }
}

extension String: SQLiteColumnDecodable {
  public init(statement: SQLiteStatement?, index: Int32) throws {
    switch SQLiteColumn(rawValue: sqlite3_column_type(statement, index)) {
    case .text:
      self = String(cString: sqlite3_column_text(statement, index))
    case let column:
      throw SQLiteDecodingError.typeMismatch(
        String.self,
        description: "Expected \(SQLiteColumn.text) but was \(column)"
      )
    }
  }
}

extension URL: SQLiteColumnDecodable {
  public init(statement: SQLiteStatement?, index: Int32) throws {
    switch SQLiteColumn(rawValue: sqlite3_column_type(statement, index)) {
    case .text:
      let absoluteString = String(cString: sqlite3_column_text(statement, index))
      guard let url = URL(string: absoluteString) else {
        throw SQLiteDecodingError.dataCorrupted(description: "Invalid URL: \(absoluteString)")
      }
      self = url
    case let column:
      throw SQLiteDecodingError.typeMismatch(
        URL.self,
        description: "Expected \(SQLiteColumn.text) but was \(column)"
      )
    }
  }
}

extension Date: SQLiteColumnDecodable {
  public init(statement: SQLiteStatement?, index: Int32) throws {
    switch SQLiteColumn(rawValue: sqlite3_column_type(statement, index)) {
    case .text:
      let timestamp = String(cString: sqlite3_column_text(statement, index))
      guard let date = utcISO8601DateFormatter.date(from: timestamp) else {
        throw SQLiteDecodingError.dataCorrupted(description: "Invalid ISO-8601 date: \(timestamp)")
      }
      self = date
    case let column:
      throw SQLiteDecodingError.typeMismatch(
        Date.self,
        description: "Expected \(SQLiteColumn.text) but was \(column)"
      )
    }
  }
}

extension Optional: SQLiteColumnDecodable where Wrapped: SQLiteColumnDecodable {
  public init(statement: SQLiteStatement?, index: Int32) throws {
    switch SQLiteColumn(rawValue: sqlite3_column_type(statement, index)) {
    case .null:
      self = nil
    default:
      self = try Wrapped(statement: statement, index: index)
    }
  }
}

public struct SQLiteDecoder {
  private var statement: SQLiteStatement?
  private var index: Int32 = 0

  private var isAtEnd: Bool { index < sqlite3_column_count(statement) }

  public init(statement: SQLiteStatement?) {
    self.statement = statement
  }

  public mutating func decodeNil() throws -> Bool {
    let isNil = sqlite3_column_type(statement, index) == SQLITE_NULL
    if isNil {
      index += 1
    }
    return isNil
  }

  public mutating func decode(_ type: Bool.Type) throws -> Bool {
    defer { index += 1 }
    return try Bool(statement: statement, index: index)
  }

  public mutating func decode(_ type: Int.Type) throws -> Int {
    defer { index += 1 }
    return try Int(statement: statement, index: index)
  }

  public mutating func decode(_ type: Double.Type) throws -> Double {
    defer { index += 1 }
    return try Double(statement: statement, index: index)
  }

  public mutating func decode(_ type: Float.Type) throws -> Float {
    defer { index += 1 }
    return try Float(statement: statement, index: index)
  }

  public mutating func decode(_ type: String.Type) throws -> String {
    defer { index += 1 }
    return try String(statement: statement, index: index)
  }

  public mutating func decode<T>(_ type: T.Type) throws -> T where T: SQLiteColumnDecodable {
    defer { index += 1 }
    return try T(statement: statement, index: index)
  }
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

  public mutating func decodeIfPresent<T>(_ type: T.Type) throws -> T? where T: SQLiteColumnDecodable {
    try decodeNil() ? nil : try decode(type)
  }
}

extension SQLiteDecoder {
  public mutating func decode(_ type: Date.Type) throws -> Date {
    defer { index += 1 }
    return try Date(statement: statement, index: index)
  }

  public mutating func decode(_ type: URL.Type) throws -> URL {
    defer { index += 1 }
    return try URL(statement: statement, index: index)
  }

  public mutating func decodeIfPresent(_ type: Date.Type) throws -> Date? {
    try decodeNil() ? nil : try decode(type)
  }

  public mutating func decodeIfPresent(_ type: URL.Type) throws -> URL? {
    try decodeNil() ? nil : try decode(type)
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
    fatalError("Unimplemented")
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
