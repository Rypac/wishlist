import SQLite3

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
  public static func fetchCursor(_ database: Database, literal: SQLLiteral) throws -> DatabaseValueCursor<Self> {
    try fetchCursor(Statement(database, literal.description).bind(literal.bindings))
  }

  public static func fetchOne(_ database: Database, literal: SQLLiteral) throws -> Self? {
    try fetchOne(Statement(database, literal.description).bind(literal.bindings))
  }

  public static func fetchAll(_ database: Database, literal: SQLLiteral) throws -> [Self] {
    try fetchAll(Statement(database, literal.description).bind(literal.bindings))
  }
}

extension DatabaseValueConvertible {
  public static func fetchCursor(_ statement: Statement) throws -> DatabaseValueCursor<Self> {
    DatabaseValueCursor<Self>(statement: statement.handle!)
  }

  public static func fetchOne(_ statement: Statement) throws -> Self? {
    let cursor = DatabaseValueCursor<Self>(statement: statement.handle!)
    return try cursor.next()
  }

  public static func fetchAll(_ statement: Statement) throws -> [Self] {
    try Array(DatabaseValueCursor<Self>(statement: statement.handle!))
  }
}

extension Optional where Wrapped: DatabaseValueConvertible {
  public static func fetchCursor(_ statement: Statement) throws -> NullableDatabaseValueCursor<Wrapped> {
    NullableDatabaseValueCursor<Wrapped>(statement: statement.handle!)
  }

  public static func fetchOne(_ statement: Statement) throws -> Wrapped?? {
    let cursor = NullableDatabaseValueCursor<Wrapped>(statement: statement.handle!)
    return try cursor.next()
  }

  public static func fetchAll(_ statement: Statement) throws -> [Wrapped?] {
    try Array(NullableDatabaseValueCursor<Wrapped>(statement: statement.handle!))
  }
}

public final class DatabaseValueCursor<Value: DatabaseValueConvertible>: Cursor {
  private let statement: SQLiteStatement

  init(statement: SQLiteStatement) {
    self.statement = statement
  }

  public func next() throws -> Value? {
    switch sqlite3_step(statement) {
    case SQLITE_DONE:
      return nil
    case SQLITE_ROW:
      let databaseValue = DatabaseValue(statement: statement, index: 0)
      if let value = Value(databaseValue: databaseValue) {
        return value
      } else {
        throw SQLiteDecodingError.valueMismatch(Self.self, databaseValue: databaseValue)
      }
    case let code:
      throw SQLiteError(code: code)
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
      return nil
    case SQLITE_ROW:
      let databaseValue = DatabaseValue(statement: statement, index: 0)
      if let value = Value(databaseValue: databaseValue) {
        return value
      } else if databaseValue.isNull {
        return nil
      } else {
        throw SQLiteDecodingError.valueMismatch(Self.self, databaseValue: databaseValue)
      }
    case let code:
      throw SQLiteError(code: code)
    }
  }
}
