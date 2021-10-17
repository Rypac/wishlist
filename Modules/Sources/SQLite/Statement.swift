import SQLite3

public final class Statement {
  private(set) var handle: SQLiteStatement
  unowned let connection: Database

  init(_ database: Database, _ sql: String) throws {
    var sqliteStatement: SQLiteStatement? = nil
    let code = sqlite3_prepare_v2(database.handle, sql, -1, &sqliteStatement, nil)
    guard code == SQLITE_OK, let statement = sqliteStatement else {
      throw SQLiteError(code: code)
    }

    self.connection = database
    self.handle = statement
  }

  deinit {
    sqlite3_finalize(handle)
  }

  /// Returns the number of columns in a result set.
  ///
  /// See <https://www.sqlite.org/c3ref/column_count.html> for more information.
  public lazy var columnCount: Int = Int(sqlite3_column_count(handle))

  /// Returns the names assigned to the columns in the result set of a `SELECT` statement.
  ///
  /// See <https://www.sqlite.org/c3ref/column_name.html> for more information.
  public lazy var columnNames: [String] = (0..<Int32(columnCount)).map { index in
    String(cString: sqlite3_column_name(handle, index))
  }

  /// Returns the raw SQL text used to create the prepared statement.
  ///
  /// See <https://www.sqlite.org/c3ref/expanded_sql.html> for more information.
  public var sql: String {
    String(cString: sqlite3_sql(handle))
  }

  /// Returns true if and only if the prepared statement makes no direct changes to the content of the database file.
  ///
  /// See <https://www.sqlite.org/c3ref/stmt_readonly.html> for more information.
  public var isReadOnly: Bool {
    sqlite3_stmt_readonly(handle) != 0
  }

  public lazy var row: Row = Row(statement: handle)
}

// MARK: - Bindings

extension Statement {
  /// Reset the prepared statement back to its initial state, ready to be re-executed.
  ///
  /// See <https://www.sqlite.org/c3ref/reset.html> for more information.
  func reset() throws {
    let code = sqlite3_reset(handle)
    guard code == SQLITE_OK else {
      throw SQLiteError(code: code, statement: handle)
    }
  }

  /// Reset all bindings on the prepared statement, clearing all host parameters to `NULL`.
  ///
  /// See <https://www.sqlite.org/c3ref/clear_bindings.html> for more information.
  func clearBindings() throws {
    let code = sqlite3_clear_bindings(handle)
    guard code == SQLITE_OK else {
      throw SQLiteError(code: code, statement: handle)
    }
  }

  public func bind(_ values: StatementBindable?...) throws -> Statement {
    try bind(values)
  }

  public func bind(_ values: [StatementBindable?]) throws -> Statement {
    try reset()
    try clearBindings()

    if values.isEmpty {
      return self
    }

    let parameterCount = Int(sqlite3_bind_parameter_count(handle))
    guard values.count == parameterCount else {
      throw SQLiteBindingError.invalidBindingCount(received: values.count, expected: parameterCount)
    }

    for index in 1...values.count {
      let result: SQLiteResultCode
      if let value = values[index - 1] {
        result = value.bind(to: handle, at: Int32(index))
      } else {
        result = sqlite3_bind_null(handle, Int32(index))
      }

      guard result == SQLITE_OK else {
        throw SQLiteError(code: result, statement: handle)
      }
    }

    return self
  }

  public func bind(_ values: [String: StatementBindable?]) throws -> Statement {
    try reset()
    try clearBindings()

    for (name, value) in values {
      let index = sqlite3_bind_parameter_index(handle, name)
      guard index > 0 else {
        throw SQLiteBindingError.noParameter(name: name)
      }

      let result: SQLiteResultCode
      if let value = value {
        result = value.bind(to: handle, at: index)
      } else {
        result = sqlite3_bind_null(handle, index)
      }

      guard result == SQLITE_OK else {
        throw SQLiteError(code: result, statement: handle)
      }
    }

    return self
  }
}

private enum SQLiteBindingError: Error {
  case noParameter(name: String)
  case invalidBindingCount(received: Int, expected: Int)
}

// MARK: - CustomStringConvertible

extension Statement: CustomStringConvertible {
  public var description: String {
    String(cString: sqlite3_sql(handle))
  }
}
