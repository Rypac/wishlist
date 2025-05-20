import Foundation
import SQLite3

public protocol DatabaseValueConvertible: StatementBindable {
  var databaseValue: DatabaseValue { get }

  init?(databaseValue: DatabaseValue)
}

extension DatabaseValueConvertible {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> SQLiteResultCode {
    switch databaseValue {
    case .null:
      sqlite3_bind_null(statement, index)
    case .integer(let int):
      sqlite3_bind_int64(statement, index, int)
    case .real(let double):
      sqlite3_bind_double(statement, index, double)
    case .text(let string):
      sqlite3_bind_text(statement, index, string, -1, SQLITE_TRANSIENT)
    case .blob(let data):
      data.withUnsafeBytes { bytes in
        sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), SQLITE_TRANSIENT)
      }
    }
  }
}

extension Bool: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .integer(self ? 1 : 0) }

  public init?(databaseValue: DatabaseValue) {
    switch databaseValue {
    case .integer(let int64):
      self = int64 == 0
    case .real(let double):
      self = !double.isZero
    default:
      return nil
    }
  }
}

extension Int: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .integer(Int64(self)) }

  public init?(databaseValue: DatabaseValue) {
    switch databaseValue {
    case .integer(let int64):
      guard let int = Int(exactly: int64) else {
        return nil
      }

      self = int
    case .real(let double):
      guard let int = Int(exactly: double) else {
        return nil
      }

      self = int
    default:
      return nil
    }
  }
}

extension Int8: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .integer(Int64(self)) }

  public init?(databaseValue: DatabaseValue) {
    switch databaseValue {
    case .integer(let int64):
      guard let int8 = Int8(exactly: int64) else {
        return nil
      }

      self = int8
    case .real(let double):
      guard let int8 = Int8(exactly: double) else {
        return nil
      }

      self = int8
    default:
      return nil
    }
  }
}

extension Int16: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .integer(Int64(self)) }

  public init?(databaseValue: DatabaseValue) {
    switch databaseValue {
    case .integer(let int64):
      guard let int16 = Int16(exactly: int64) else {
        return nil
      }

      self = int16
    case .real(let double):
      guard let int16 = Int16(exactly: double) else {
        return nil
      }

      self = int16
    default:
      return nil
    }
  }
}

extension Int32: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .integer(Int64(self)) }

  public init?(databaseValue: DatabaseValue) {
    switch databaseValue {
    case .integer(let int64):
      guard let int32 = Int32(exactly: int64) else {
        return nil
      }

      self = int32
    case .real(let double):
      guard let int32 = Int32(exactly: double) else {
        return nil
      }

      self = int32
    default:
      return nil
    }
  }
}

extension Int64: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .integer(self) }

  public init?(databaseValue: DatabaseValue) {
    switch databaseValue {
    case .integer(let int64):
      self = int64
    case .real(let double):
      guard let int64 = Int64(exactly: double) else {
        return nil
      }

      self = int64
    default:
      return nil
    }
  }
}

extension Float: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .real(Double(self)) }

  public init?(databaseValue: DatabaseValue) {
    switch databaseValue {
    case .integer(let int64):
      self = Float(int64)
    case .real(let double):
      self = Float(double)
    default:
      return nil
    }
  }
}

extension Double: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .real(self) }

  public init?(databaseValue: DatabaseValue) {
    switch databaseValue {
    case .integer(let int64):
      self = Double(int64)
    case .real(let double):
      self = double
    default:
      return nil
    }
  }
}

extension String: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .text(self) }

  public init?(databaseValue: DatabaseValue) {
    switch databaseValue {
    case .text(let string):
      self = string
    case .blob(let data):
      guard let string = String(data: data, encoding: .utf8) else {
        return nil
      }

      self = string
    default:
      return nil
    }
  }
}

extension URL: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .text(absoluteString) }

  public init?(databaseValue: DatabaseValue) {
    guard case .text(let string) = databaseValue, let url = URL(string: string) else {
      return nil
    }

    self = url
  }
}

extension UUID: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .text(uuidString) }

  public init?(databaseValue: DatabaseValue) {
    guard case .text(let string) = databaseValue, let uuid = UUID(uuidString: string) else {
      return nil
    }

    self = uuid
  }
}

extension Data: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .blob(self) }

  public init?(databaseValue: DatabaseValue) {
    switch databaseValue {
    case .blob(let data):
      self = data
    case .text(let string):
      guard let data = string.data(using: .utf8) else {
        return nil
      }

      self = data
    default:
      return nil
    }
  }
}

@available(macOS 10.12, *)
extension Date: DatabaseValueConvertible {
  static let utcISO8601DateFormatter = ISO8601DateFormatter()

  public var databaseValue: DatabaseValue {
    .text(Date.utcISO8601DateFormatter.string(from: self))
  }

  public init?(databaseValue: DatabaseValue) {
    switch databaseValue {
    case .text(let string):
      guard let date = Date.utcISO8601DateFormatter.date(from: string) else {
        return nil
      }

      self = date
    case .integer(let int64):
      self = Date(timeIntervalSince1970: Double(int64))
    case .real(let double):
      self = Date(timeIntervalSince1970: double)
    default:
      return nil
    }
  }
}

extension DatabaseValueConvertible where Self: RawRepresentable, RawValue: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { rawValue.databaseValue }

  public init?(databaseValue: DatabaseValue) {
    guard let rawValue = RawValue(databaseValue: databaseValue) else {
      return nil
    }

    self.init(rawValue: rawValue)
  }
}

// MARK: - Fetching

extension DatabaseValueConvertible {
  public static func fetchCursor(_ database: Database, sql: String) throws -> DatabaseValueCursor<Self> {
    try fetchCursor(Statement(database, sql))
  }

  public static func fetchOne(_ database: Database, sql: String) throws -> Self? {
    try fetchOne(Statement(database, sql))
  }

  public static func fetchAll(_ database: Database, sql: String) throws -> [Self] {
    try fetchAll(Statement(database, sql))
  }
}

extension DatabaseValueConvertible {
  public static func fetchCursor(_ database: Database, literal: SQL) throws -> DatabaseValueCursor<Self> {
    try fetchCursor(Statement(database, literal.description).bind(literal.bindings))
  }

  public static func fetchOne(_ database: Database, literal: SQL) throws -> Self? {
    try fetchOne(Statement(database, literal.description).bind(literal.bindings))
  }

  public static func fetchAll(_ database: Database, literal: SQL) throws -> [Self] {
    try fetchAll(Statement(database, literal.description).bind(literal.bindings))
  }
}

extension DatabaseValueConvertible {
  public static func fetchCursor(_ statement: Statement) throws -> DatabaseValueCursor<Self> {
    DatabaseValueCursor<Self>(statement: statement.handle)
  }

  public static func fetchOne(_ statement: Statement) throws -> Self? {
    let cursor = DatabaseValueCursor<Self>(statement: statement.handle)
    return try cursor.next()
  }

  public static func fetchAll(_ statement: Statement) throws -> [Self] {
    try Array(DatabaseValueCursor<Self>(statement: statement.handle))
  }
}

extension Optional where Wrapped: DatabaseValueConvertible {
  public static func fetchCursor(_ statement: Statement) throws -> NullableDatabaseValueCursor<Wrapped> {
    NullableDatabaseValueCursor<Wrapped>(statement: statement.handle)
  }

  public static func fetchOne(_ statement: Statement) throws -> Wrapped?? {
    let cursor = NullableDatabaseValueCursor<Wrapped>(statement: statement.handle)
    return try cursor.next()
  }

  public static func fetchAll(_ statement: Statement) throws -> [Wrapped?] {
    try Array(NullableDatabaseValueCursor<Wrapped>(statement: statement.handle))
  }
}

// MARK: - Cursors

public final class DatabaseValueCursor<Value: DatabaseValueConvertible>: Cursor {
  private let statement: SQLiteStatement

  init(statement: SQLiteStatement) {
    self.statement = statement
  }

  public func next() throws -> Value? {
    switch sqlite3_step(statement) {
    case SQLITE_DONE:
      nil
    case SQLITE_ROW:
      try Value.decode(fromStatement: statement, atIndex: 0)
    case let code:
      throw SQLiteError(code: code, statement: statement)
    }
  }
}

public final class NullableDatabaseValueCursor<Value: DatabaseValueConvertible>: Cursor {
  private let statement: SQLiteStatement

  init(statement: SQLiteStatement) {
    self.statement = statement
  }

  public func next() throws -> Value?? {
    switch sqlite3_step(statement) {
    case SQLITE_DONE:
      nil
    case SQLITE_ROW:
      try Value.decodeIfPresent(fromStatement: statement, atIndex: 0)
    case let code:
      throw SQLiteError(code: code, statement: statement)
    }
  }
}

// MARK: - Decoding

extension DatabaseValueConvertible {
  static func decode(fromStatement statement: SQLiteStatement, atIndex index: Int32) throws -> Self {
    let databaseValue = DatabaseValue(statement: statement, index: index)
    guard let value = Self(databaseValue: databaseValue) else {
      throw SQLiteDecodingError.valueMismatch(Self.self, databaseValue: databaseValue)
    }
    return value
  }

  static func decodeIfPresent(fromStatement statement: SQLiteStatement, atIndex index: Int32) throws -> Self? {
    let databaseValue = DatabaseValue(statement: statement, index: index)
    if let value = Self(databaseValue: databaseValue) {
      return value
    } else if databaseValue.isNull {
      return nil
    } else {
      throw SQLiteDecodingError.valueMismatch(Self.self, databaseValue: databaseValue)
    }
  }
}
