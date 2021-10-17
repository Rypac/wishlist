import Foundation
import SQLite3

public protocol Record {
  init(row: Row) throws
}

// MARK: - Fetching

extension Record {
  public static func fetchCursor(_ database: Database, sql: String) throws -> RecordCurser<Self> {
    try fetchCursor(Statement(database, sql))
  }

  public static func fetchOne(_ database: Database, sql: String) throws -> Self? {
    try fetchOne(Statement(database, sql))
  }

  public static func fetchAll(_ database: Database, sql: String) throws -> [Self] {
    try fetchAll(Statement(database, sql))
  }
}

extension Record {
  public static func fetchCursor(_ database: Database, literal: SQL) throws -> RecordCurser<Self> {
    try fetchCursor(Statement(database, literal.description).bind(literal.bindings))
  }

  public static func fetchOne(_ database: Database, literal: SQL) throws -> Self? {
    try fetchOne(Statement(database, literal.description).bind(literal.bindings))
  }

  public static func fetchAll(_ database: Database, literal: SQL) throws -> [Self] {
    try fetchAll(Statement(database, literal.description).bind(literal.bindings))
  }
}

extension Record {
  public static func fetchCursor(_ statement: Statement) throws -> RecordCurser<Self> {
    RecordCurser<Self>(statement: statement.handle, row: statement.row)
  }

  public static func fetchOne(_ statement: Statement) throws -> Self? {
    let cursor = RecordCurser<Self>(statement: statement.handle, row: statement.row)
    return try cursor.next()
  }

  public static func fetchAll(_ statement: Statement) throws -> [Self] {
    try Array(RecordCurser<Self>(statement: statement.handle, row: statement.row))
  }
}

// MARK: - Cursor

public class RecordCurser<Value: Record>: Cursor {
  private let statement: SQLiteStatement
  private let row: Row

  init(statement: SQLiteStatement, row: Row) {
    self.statement = statement
    self.row = row
  }

  public func next() throws -> Value? {
    switch sqlite3_step(statement) {
    case SQLITE_DONE:
      return nil
    case SQLITE_ROW:
      return try Value(row: row)
    case let code:
      throw SQLiteError(code: code, statement: statement)
    }
  }
}
