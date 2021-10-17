import SQLite3

public struct Row {
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
      try Value.decodeIfPresent(fromStatement: statement, atIndex: Int32(index))
    }
  }

  public subscript<Value: DatabaseValueConvertible>(_ index: Int) -> Value {
    get throws {
      try Value.decode(fromStatement: statement, atIndex: Int32(index))
    }
  }

  public subscript<Value: DatabaseValueConvertible & StatementConvertible>(_ index: Int) -> Value? {
    get throws {
      try Value.decodeIfPresent(fromStatement: statement, atIndex: Int32(index))
    }
  }

  public subscript<Value: DatabaseValueConvertible & StatementConvertible>(_ index: Int) -> Value {
    get throws {
      try Value.decode(fromStatement: statement, atIndex: Int32(index))
    }
  }
}

enum SQLiteDecodingError: Error {
  case failure
  case valueMismatch(_ type: Any.Type, databaseValue: DatabaseValue)
}
