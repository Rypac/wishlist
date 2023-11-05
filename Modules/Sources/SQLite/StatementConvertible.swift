import Foundation
import SQLite3

public protocol StatementConvertible {
  init?(statement: SQLiteStatement, index: Int32)
}

extension Bool: StatementConvertible {
  public init(statement: SQLiteStatement, index: Int32) {
    self = sqlite3_column_int64(statement, index) != 0
  }
}

extension Int: StatementConvertible {
  public init?(statement: SQLiteStatement, index: Int32) {
    guard let int = Int(exactly: sqlite3_column_int64(statement, index)) else {
      return nil
    }

    self = int
  }
}

extension Int8: StatementConvertible {
  public init?(statement: SQLiteStatement, index: Int32) {
    guard let int8 = Int8(exactly: sqlite3_column_int64(statement, index)) else {
      return nil
    }

    self = int8
  }
}

extension Int16: StatementConvertible {
  public init?(statement: SQLiteStatement, index: Int32) {
    guard let int16 = Int16(exactly: sqlite3_column_int64(statement, index)) else {
      return nil
    }

    self = int16
  }
}

extension Int32: StatementConvertible {
  public init?(statement: SQLiteStatement, index: Int32) {
    guard let int32 = Int32(exactly: sqlite3_column_int64(statement, index)) else {
      return nil
    }

    self = int32
  }
}

extension Int64: StatementConvertible {
  public init(statement: SQLiteStatement, index: Int32) {
    self = sqlite3_column_int64(statement, index)
  }
}

extension Float: StatementConvertible {
  public init?(statement: SQLiteStatement, index: Int32) {
    guard let float = Float(exactly: sqlite3_column_double(statement, index)) else {
      return nil
    }

    self = float
  }
}

extension Double: StatementConvertible {
  public init(statement: SQLiteStatement, index: Int32) {
    self = sqlite3_column_double(statement, index)
  }
}

extension String: StatementConvertible {
  public init(statement: SQLiteStatement, index: Int32) {
    self = String(cString: sqlite3_column_text(statement, index))
  }
}

extension Data: StatementConvertible {
  public init(statement: SQLiteStatement, index: Int32) {
    if let bytes = sqlite3_column_blob(statement, index) {
      self = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, index)))
    } else {
      self = Data()
    }
  }
}

extension StatementConvertible where Self: RawRepresentable, RawValue: StatementConvertible {
  public init?(statement: SQLiteStatement, index: Int32) {
    guard let rawValue = RawValue(statement: statement, index: index) else {
      return nil
    }

    self.init(rawValue: rawValue)
  }
}

// MARK: - Fetching

extension DatabaseValueConvertible where Self: StatementConvertible {
  public static func fetchCursor(_ database: Database, sql: String) throws -> FastDatabaseValueCursor<Self> {
    try fetchCursor(Statement(database, sql))
  }

  public static func fetchOne(_ database: Database, sql: String) throws -> Self? {
    try fetchOne(Statement(database, sql))
  }

  public static func fetchAll(_ database: Database, sql: String) throws -> [Self] {
    try fetchAll(Statement(database, sql))
  }
}

extension DatabaseValueConvertible where Self: StatementConvertible {
  public static func fetchCursor(_ database: Database, literal: SQL) throws -> FastDatabaseValueCursor<Self> {
    try fetchCursor(Statement(database, literal.description).bind(literal.bindings))
  }

  public static func fetchOne(_ database: Database, literal: SQL) throws -> Self? {
    try fetchOne(Statement(database, literal.description).bind(literal.bindings))
  }

  public static func fetchAll(_ database: Database, literal: SQL) throws -> [Self] {
    try fetchAll(Statement(database, literal.description).bind(literal.bindings))
  }
}

extension DatabaseValueConvertible where Self: StatementConvertible {
  public static func fetchCursor(_ statement: Statement) throws -> FastDatabaseValueCursor<Self> {
    FastDatabaseValueCursor<Self>(statement: statement.handle)
  }

  public static func fetchOne(_ statement: Statement) throws -> Self? {
    let cursor = FastDatabaseValueCursor<Self>(statement: statement.handle)
    return try cursor.next()
  }

  public static func fetchAll(_ statement: Statement) throws -> [Self] {
    try Array(FastDatabaseValueCursor<Self>(statement: statement.handle))
  }
}

extension Optional where Wrapped: DatabaseValueConvertible & StatementConvertible {
  public static func fetchCursor(_ statement: Statement) throws -> FastNullableDatabaseValueCursor<Wrapped> {
    FastNullableDatabaseValueCursor<Wrapped>(statement: statement.handle)
  }

  public static func fetchOne(_ statement: Statement) throws -> Wrapped?? {
    let cursor = FastNullableDatabaseValueCursor<Wrapped>(statement: statement.handle)
    return try cursor.next()
  }

  public static func fetchAll(_ statement: Statement) throws -> [Wrapped?] {
    try Array(FastNullableDatabaseValueCursor<Wrapped>(statement: statement.handle))
  }
}

// MARK: - Cursor

public final class FastDatabaseValueCursor<Value: DatabaseValueConvertible & StatementConvertible>: Cursor {
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

public final class FastNullableDatabaseValueCursor<Value: DatabaseValueConvertible & StatementConvertible>: Cursor {
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

extension DatabaseValueConvertible where Self: StatementConvertible {
  static func decode(fromStatement statement: SQLiteStatement, atIndex index: Int32) throws -> Self {
    guard
      sqlite3_column_type(statement, index) != SQLITE_NULL,
      let value = Self(statement: statement, index: index)
    else {
      throw SQLiteDecodingError.failure
    }

    return value
  }

  static func decodeIfPresent(fromStatement statement: SQLiteStatement, atIndex index: Int32) throws -> Self? {
    if sqlite3_column_type(statement, index) == SQLITE_NULL {
      return nil
    } else if let value = Self(statement: statement, index: index) {
      return value
    } else {
      throw SQLiteDecodingError.failure
    }
  }
}

enum SQLiteDecodingError: Error {
  case failure
  case valueMismatch(_ type: Any.Type, databaseValue: DatabaseValue)
}
