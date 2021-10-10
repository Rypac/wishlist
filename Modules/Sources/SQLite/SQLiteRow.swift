import SQLite3

public protocol SQLiteRowDecodable {
  init(row: SQLiteRow) throws
}

public struct SQLiteRow {
  public let statement: SQLiteStatement

  public init(statement: SQLiteStatement) {
    self.statement = statement
  }

  /// Returns the number of columns in the row.
  ///
  /// See <https://www.sqlite.org/c3ref/column_count.html> for more information.
  public var count: Int {
    Int(sqlite3_column_count(statement))
  }

  public subscript<Value: DatabaseValueConvertible>(_ index: Int) -> Value? {
    get throws {
      let databaseValue = DatabaseValue(statement: statement, index: Int32(index))
      if let value = Value(databaseValue: databaseValue) {
        return value
      } else if databaseValue.isNull {
        return nil
      } else {
        throw SQLiteDecodingError.valueMismatch(Self.self, databaseValue: databaseValue)
      }
    }
  }

  public subscript<Value: DatabaseValueConvertible>(_ index: Int) -> Value {
    get throws {
      let databaseValue = DatabaseValue(statement: statement, index: Int32(index))
      if let value = Value(databaseValue: databaseValue) {
        return value
      } else {
        throw SQLiteDecodingError.valueMismatch(Self.self, databaseValue: databaseValue)
      }
    }
  }

  public subscript<Value: DatabaseValueConvertible & StatementConvertible>(_ index: Int) -> Value? {
    get throws {
      let index = Int32(index)
      if sqlite3_column_type(statement, index) == SQLITE_NULL {
        return nil
      } else if let value = Value(statement: statement, index: index) {
        return value
      } else {
        throw SQLiteDecodingError.failure
      }
    }
  }

  public subscript<Value: DatabaseValueConvertible & StatementConvertible>(_ index: Int) -> Value {
    get throws {
      if let value = Value(statement: statement, index: Int32(index)) {
        return value
      } else {
        throw SQLiteDecodingError.failure
      }
    }
  }
}

private enum SQLiteDecodingError: Error {
  case failure
  case valueMismatch(_ type: Any.Type, databaseValue: DatabaseValue)
}
