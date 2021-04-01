import Foundation
import SQLite3

typealias SQLiteStatement = OpaquePointer

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private let utcISO8601DateFormatter = ISO8601DateFormatter()

public final class SQLite {
  public private(set) var handle: OpaquePointer?

  public init(path: String) throws {
    try validate(
      sqlite3_open_v2(
        path,
        &handle,
        SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE,
        nil
      )
    )
  }

  deinit {
    sqlite3_close_v2(handle)
  }

  public func execute(_ sql: String) throws {
    try validate(sqlite3_exec(handle, sql, nil, nil, nil))
  }

  public func execute(_ sql: String, _ bindings: SQLiteEncodable...) throws {
    var statement: SQLiteStatement?
    try validate(sqlite3_prepare_v2(handle, sql, -1, &statement, nil))
    defer { sqlite3_finalize(statement) }

    var encoder = SQLiteEncoder(statement: statement)
    for binding in bindings {
      try encoder.encode(binding)
    }

    try validate(sqlite3_step(statement))
  }

  public func run<Row: SQLiteDecodable>(_ sql: String, _ bindings: SQLiteEncodable...) throws -> [Row] {
    var statement: SQLiteStatement?
    try validate(sqlite3_prepare_v2(handle, sql, -1, &statement, nil))
    defer { sqlite3_finalize(statement) }

    var encoder = SQLiteEncoder(statement: statement)
    for binding in bindings {
      try encoder.encode(binding)
    }

    var rows: [Row] = []
    while try validate(sqlite3_step(statement)) == SQLITE_ROW {
      var decoder = SQLiteDecoder(statement: statement)
      rows.append(try Row(from: &decoder))
    }

    return rows
  }

  @discardableResult
  private func validate(_ code: Int32) throws -> Int32 {
    guard code == SQLITE_OK || code == SQLITE_ROW || code == SQLITE_DONE else {
      throw Error(code: code)
    }
    return code
  }

  public struct Error: Swift.Error, Equatable {
    public var code: Int32
    public var description: String
  }
}

private extension SQLite.Error {
  init(code: Int32) {
    self.code = code
    self.description = String(cString: sqlite3_errstr(code))
  }
}

public typealias SQLiteCodable = SQLiteDecodable & SQLiteEncodable

// MARK: - Decoding

public protocol SQLiteDecodable {
  init(from decoder: inout SQLiteDecoder) throws
}

enum SQLiteDecodingError: Error {
  case typeMismatch(Any.Type, description: String)
  case dataCorrupted(description: String)
  case exceededColumnCount(index: Int)
}

extension Bool: SQLiteDecodable {
  public init(from decoder: inout SQLiteDecoder) throws {
    self = try decoder.decode(Bool.self)
  }
}

extension Int: SQLiteDecodable {
  public init(from decoder: inout SQLiteDecoder) throws {
    self = try decoder.decode(Int.self)
  }
}

extension Double: SQLiteDecodable {
  public init(from decoder: inout SQLiteDecoder) throws {
    self = try decoder.decode(Double.self)
  }
}

extension Float: SQLiteDecodable {
  public init(from decoder: inout SQLiteDecoder) throws {
    self = try decoder.decode(Float.self)
  }
}

extension String: SQLiteDecodable {
  public init(from decoder: inout SQLiteDecoder) throws {
    self = try decoder.decode(String.self)
  }
}

extension URL: SQLiteDecodable {
  public init(from decoder: inout SQLiteDecoder) throws {
    let absoluteString = try decoder.decode(String.self)
    guard let url = URL(string: absoluteString) else {
      throw SQLiteDecodingError.dataCorrupted(description: "Invalid URL: \(absoluteString)")
    }

    self = url
  }
}

extension Date: SQLiteDecodable {
  public init(from decoder: inout SQLiteDecoder) throws {
    let timestamp = try decoder.decode(String.self)
    guard let date = utcISO8601DateFormatter.date(from: timestamp) else {
      throw SQLiteDecodingError.dataCorrupted(description: "Invalid ISO-8601 date: \(timestamp)")
    }

    self = date
  }
}

extension Optional: SQLiteDecodable where Wrapped: SQLiteDecodable {
  public init(from decoder: inout SQLiteDecoder) throws {
    if try decoder.decodeNil() {
      self = nil
    } else {
      self = try decoder.decode(Wrapped.self)
    }
  }
}

extension SQLiteDecodable where Self: RawRepresentable, RawValue: SQLiteDecodable {
  public init(from decoder: inout SQLiteDecoder) throws {
    guard let value = Self.init(rawValue: try decoder.decode(RawValue.self)) else {
      throw SQLiteDecodingError.dataCorrupted(description: "Invalid raw value")
    }
    self = value
  }
}

public struct SQLiteDecoder {
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

  public mutating func decodeNil() throws -> Bool {
    try checkIndex()
    let isNil = sqlite3_column_type(statement, index) == SQLITE_NULL
    if isNil {
      index += 1
    }
    return isNil
  }

  public mutating func decode(_ type: Bool.Type) throws -> Bool {
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

  public mutating func decode(_ type: Int.Type) throws -> Int {
    try checkIndex()
    defer { index += 1 }
    switch sqlite3_column_type(statement, index) {
    case SQLITE_INTEGER:
      return Int(sqlite3_column_int64(statement, index))
    default:
      throw SQLiteDecodingError.typeMismatch(Int.self, description: "Expected INTEGER")
    }
  }

  public mutating func decode(_ type: Double.Type) throws -> Double {
    try checkIndex()
    defer { index += 1 }
    switch sqlite3_column_type(statement, index) {
    case SQLITE_FLOAT:
      return sqlite3_column_double(statement, index)
    default:
      throw SQLiteDecodingError.typeMismatch(Double.self, description: "Expected REAL")
    }
  }

  public mutating func decode(_ type: Float.Type) throws -> Float {
    try checkIndex()
    defer { index += 1 }
    switch sqlite3_column_type(statement, index) {
    case SQLITE_FLOAT:
      return Float(sqlite3_column_double(statement, index))
    default:
      throw SQLiteDecodingError.typeMismatch(Float.self, description: "Expected REAL")
    }
  }

  public mutating func decode(_ type: String.Type) throws -> String {
    try checkIndex()
    defer { index += 1 }
    switch sqlite3_column_type(statement, index) {
    case SQLITE_TEXT:
      return String(cString: sqlite3_column_text(statement, index))
    default:
      throw SQLiteDecodingError.typeMismatch(String.self, description: "Expected TEXT")
    }
  }

  public mutating func decode(_ type: Data.Type) throws -> Data {
    try checkIndex()
    defer { index += 1 }
    switch sqlite3_column_type(statement, index) {
    case SQLITE_BLOB:
      return sqlite3_column_blob(statement, index).load(as: Data.self)
    default:
      throw SQLiteDecodingError.typeMismatch(Data.self, description: "Expected BLOB")
    }
  }

  public mutating func decode<T>(_ type: T.Type) throws -> T where T: SQLiteDecodable {
    try T(from: &self)
  }
}

// MARK: - Encoding

public protocol SQLiteEncodable {
  func encode(to encoder: inout SQLiteEncoder) throws
}

extension Bool: SQLiteEncodable {
  public func encode(to encoder: inout SQLiteEncoder) throws {
    try encoder.encode(self)
  }
}

extension Int: SQLiteEncodable {
  public func encode(to encoder: inout SQLiteEncoder) throws {
    try encoder.encode(self)
  }
}

extension Double: SQLiteEncodable {
  public func encode(to encoder: inout SQLiteEncoder) throws {
    try encoder.encode(self)
  }
}

extension Float: SQLiteEncodable {
  public func encode(to encoder: inout SQLiteEncoder) throws {
    try encoder.encode(Double(self))
  }
}

extension String: SQLiteEncodable {
  public func encode(to encoder: inout SQLiteEncoder) throws {
    try encoder.encode(self)
  }
}

extension Date: SQLiteEncodable {
  public func encode(to encoder: inout SQLiteEncoder) throws {
    try encoder.encode(utcISO8601DateFormatter.string(from: self))
  }
}

extension URL: SQLiteEncodable {
  public func encode(to encoder: inout SQLiteEncoder) throws {
    try encoder.encode(absoluteString)
  }
}

extension Optional: SQLiteEncodable where Wrapped: SQLiteEncodable {
  public func encode(to encoder: inout SQLiteEncoder) throws {
    if let value = self {
      try encoder.encode(value)
    } else {
      try encoder.encodeNil()
    }
  }
}

extension SQLiteEncodable where Self: RawRepresentable, RawValue: SQLiteEncodable {
  public func encode(to encoder: inout SQLiteEncoder) throws {
    try encoder.encode(rawValue)
  }
}

public struct SQLiteEncoder {
  private var statement: SQLiteStatement?
  private var index: Int32 = 1

  init(statement: SQLiteStatement?) {
    self.statement = statement
  }

  private func checkIndex() throws {
    let bindingCount = sqlite3_bind_parameter_count(statement)
    guard index < bindingCount else {
      throw SQLiteEncodingError.tooManyBindings(count: Int(bindingCount))
    }
  }

  public mutating func encodeNil() throws {
    defer { index += 1 }
    let result = sqlite3_bind_null(statement, index)
    guard result == SQLITE_OK else {
      throw SQLiteEncodingError.invalid(code: result)
    }
  }

  public mutating func encode(_ value: Bool) throws {
    defer { index += 1 }
    let result = sqlite3_bind_int64(statement, index, value ? 1 : 0)
    guard result == SQLITE_OK else {
      throw SQLiteEncodingError.invalid(code: result)
    }
  }

  public mutating func encode(_ value: Int) throws {
    defer { index += 1 }
    let result = sqlite3_bind_int64(statement, index, Int64(value))
    guard result == SQLITE_OK else {
      throw SQLiteEncodingError.invalid(code: result)
    }
  }

  public mutating func encode(_ value: Double) throws {
    defer { index += 1 }
    let result = sqlite3_bind_double(statement, index, value)
    guard result == SQLITE_OK else {
      throw SQLiteEncodingError.invalid(code: result)
    }
  }

  public mutating func encode(_ value: String) throws {
    defer { index += 1 }
    let result = sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
    guard result == SQLITE_OK else {
      throw SQLiteEncodingError.invalid(code: result)
    }
  }

  public mutating func encode(_ value: Data) throws {
    defer { index += 1 }
    try value.withUnsafeBytes { bytes in
      let result = sqlite3_bind_blob(statement, index, bytes.baseAddress, -1, SQLITE_TRANSIENT)
      guard result == SQLITE_OK else {
        throw SQLiteEncodingError.invalid(code: result)
      }
    }
  }

  public mutating func encode(_ value: SQLiteEncodable) throws {
    try value.encode(to: &self)
  }
}

public enum SQLiteEncodingError: Error {
  case invalid(code: Int32)
  case tooManyBindings(count: Int)
}
