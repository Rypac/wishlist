import Foundation
import SQLite3

public final class Statement {

  var handle: SQLiteStatement?

  let connection: SQLiteDatabase

  init(_ connection: SQLiteDatabase, _ sql: String) throws {
    self.connection = connection
    try connection.validate(sqlite3_prepare_v2(connection.handle, sql, -1, &handle, nil))
  }

  deinit {
    sqlite3_finalize(handle)
  }

  /// Returns the number of columns in a result set.
  ///
  /// See also:
  ///   [sqlite3_column_count](https://www.sqlite.org/c3ref/column_count.html)
  public lazy var columnCount: Int = Int(sqlite3_column_count(handle))

  public lazy var columnNames: [String] = (0..<Int32(columnCount)).map {
    String(cString: sqlite3_column_name(handle, $0))
  }

  public lazy var row: SQLiteRow = SQLiteRow(statement: handle!)

  /// Evaluate the prepared statement.
  ///
  /// See also:
  ///   [sqlite3_step](https://www.sqlite.org/c3ref/step.html)
  public func step() throws -> Bool {
    try connection.validate(sqlite3_step(handle)) == SQLITE_ROW
  }

  /// Reset the statement back to its initial state, ready to be re-executed.
  ///
  /// - Parameters:
  ///   - clearingBindings: Whether the bound parameters should also be cleared.
  ///
  /// See also:
  ///   [sqlite3_reset](https://www.sqlite.org/c3ref/reset.html),
  ///   [sqlite3_clear_bindings](https://www.sqlite.org/c3ref/clear_bindings.html)
  func reset(clearingBindings shouldClearBindings: Bool = true) {
    sqlite3_reset(handle)
    if shouldClearBindings {
      sqlite3_clear_bindings(handle)
    }
  }
}

// MARK: - Bindings

extension Statement {
  public func bind(_ values: StatementBindable?...) throws -> Statement {
    try bind(values)
  }

  public func bind(_ values: [StatementBindable?]) throws -> Statement {
    if values.isEmpty {
      return self
    }

    reset()

    let parameterCount = Int(sqlite3_bind_parameter_count(handle))
    guard values.count == parameterCount else {
      throw SQLiteBindingError.invalidBindingCount(received: values.count, expected: parameterCount)
    }

    for index in 1...values.count {
      if let value = values[index - 1] {
        value.bind(to: handle!, at: Int32(index))
      } else {
        sqlite3_bind_null(handle!, Int32(index))
      }
    }

    return self
  }

  public func bind(_ values: [String: StatementBindable?]) throws -> Statement {
    reset()

    for (name, value) in values {
      let index = sqlite3_bind_parameter_index(handle, name)

      guard index > 0 else {
        throw SQLiteBindingError.noParameter(name: name)
      }

      if let value = value {
        value.bind(to: handle!, at: index)
      } else {
        sqlite3_bind_null(handle!, Int32(index))
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
