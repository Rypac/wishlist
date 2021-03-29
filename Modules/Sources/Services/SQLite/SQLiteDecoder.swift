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

private let utcISO8601DateFormatter = ISO8601DateFormatter()

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
