import Foundation
import SQLite3

public typealias SQLiteStatement = OpaquePointer

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class Database {
  private(set) var handle: OpaquePointer? = nil
  let configuration: DatabaseConfiguration

  init(
    location: DatabaseLocation,
    configuration: DatabaseConfiguration = DatabaseConfiguration()
  ) throws {
    self.configuration = configuration
    let flags = configuration.readOnly ? SQLITE_OPEN_CREATE : SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE
    try validate(sqlite3_open_v2(location.path, &handle, flags, nil))
    try applyConfiguration()
  }

  deinit {
    sqlite3_close_v2(handle)
  }

  private func applyConfiguration() throws {
    try execute {
      "PRAGMA foreign_keys = \(configuration.foreignKeysEnabled ? "ON" : "OFF");"
      "PRAGMA journal_mode = \(configuration.journalMode);"
      if case .wal = configuration.journalMode {
        "PRAGMA synchronous = NORMAL;"
      }
    }
  }

  /// Returns the rowid of the most recent successful `INSERT` into a rowid table.
  ///
  /// If no successful `INSERT`s into rowid tables have ever occurred on the database connection this returns `0`.
  ///
  /// See <https://www.sqlite.org/c3ref/last_insert_rowid.html> for more information.
  public var lastInsertRowId: Int64 {
    sqlite3_last_insert_rowid(handle)
  }

  /// Returns the number of rows modified, inserted or deleted by the most recently completed `INSERT`, `UPDATE` or `DELETE` statement.
  ///
  /// See <https://www.sqlite.org/c3ref/changes.html> for more information.
  public var changes: Int {
    Int(sqlite3_changes(handle))
  }

  /// Returns the number of rows modified, inserted or deleted by the most all completed `INSERT`, `UPDATE` or `DELETE` statements since the database was opened.
  ///
  /// See <https://www.sqlite.org/c3ref/total_changes.html> for more information.
  public var totalChanges: Int {
    Int(sqlite3_total_changes(handle))
  }

  /// Executes an SQL statement.
  ///
  /// - Parameters:
  ///   - sql: The SQL to be evaluated.
  ///
  /// See <https://www.sqlite.org/c3ref/exec.html> for more information.
  public func execute(sql: String) throws {
    try validate(sqlite3_exec(handle, sql, nil, nil, nil))
  }

  /// Executes an SQL statement.
  ///
  /// - Parameters:
  ///   - sql: The SQL query builder to be evaluated.
  ///
  /// See <https://www.sqlite.org/c3ref/exec.html> for more information.
  public func execute(@SQLBuilder sql: () -> String) throws {
    try execute(sql: sql())
  }

  public func execute(sql: String, bindings: StatementBindable?...) throws {
    try execute(sql: sql, bindings: bindings)
  }

  public func execute(sql: String, bindings: [StatementBindable?]) throws {
    let statement = try Statement(self, sql).bind(bindings)
    _ = try statement.step()
  }

  public func execute(literal: SQLLiteral) throws {
    if literal.bindings.isEmpty {
      try execute(sql: literal.description)
    } else {
      try execute(sql: literal.description, bindings: literal.bindings)
    }
  }

  public func run<Row: SQLiteRowDecodable>(literal: SQLLiteral) throws -> [Row] {
    if literal.bindings.isEmpty {
      return try run(sql: literal.description)
    } else {
      return try run(sql: literal.description, bindings: literal.bindings)
    }
  }

  public func run<Row: SQLiteRowDecodable>(sql: String) throws -> [Row] {
    let statement = try Statement(self, sql)

    var rows: [Row] = []
    while try statement.step() {
      rows.append(try Row(row: statement.row))
    }

    return rows
  }

  public func run<Row: SQLiteRowDecodable>(sql: String, bindings: StatementBindable?...) throws -> [Row] {
    try run(sql: sql, bindings: bindings)
  }

  public func run<Row: SQLiteRowDecodable>(sql: String, bindings: [StatementBindable?]) throws -> [Row] {
    let statement = try Statement(self, sql).bind(bindings)

    var rows: [Row] = []
    while try statement.step() {
      rows.append(try Row(row: statement.row))
    }

    return rows
  }

  public func transaction(mode: TransactionMode? = nil, execute work: () throws -> Void) throws {
    let transactionMode = mode ?? configuration.defaultTransactionMode
    try execute(sql: "BEGIN \(transactionMode) TRANSACTION;")
    do {
      try work()
      try execute(sql: "COMMIT;")
    } catch {
      try execute(sql: "ROLLBACK TRANSACTION;")
      throw error
    }
  }

  /// Interrupt a long-running query.
  ///
  /// This causes any pending database operation to abort and return at its earliest opportunity.
  ///
  /// See <https://www.sqlite.org/c3ref/interrupt.html> for more information.
  public func interrupt() {
    sqlite3_interrupt(handle)
  }
}

extension Database {
  /// Rebuilds the database file, repacking it into a minimal amount of disk space.
  ///
  /// See <https://www.sqlite.org/lang_vacuum.html> for more information.
  public func vacuum() throws {
    try execute(sql: "VACUUM;")
  }

  /// Creates a new database file at the specified path with a minimum amount of disk space.
  ///
  /// See <https://www.sqlite.org/lang_vacuum.html#vacuuminto> for more information.
  public func vacuum(into filePath: String) throws {
    try execute(literal: "VACUUM INTO \(filePath);")
  }
}

extension Database {
  /// Returns whether the database connection is read-only.
  ///
  /// See <https://www.sqlite.org/c3ref/db_readonly.html> for more information.
  public var isReadOnly: Bool {
    sqlite3_db_readonly(handle, nil) == 1
  }

  /// Prevents data changes on database files until ended.
  ///
  /// When in read-only mode, any attempt to `CREATE`, `DELETE`, `DROP`, `INSERT`, or `UPDATE`
  /// will result in an `SQLITE_READONLY` error.
  ///
  /// See <https://www.sqlite.org/pragma.html#pragma_query_only> for more information.
  public func beginReadOnly() throws {
    try execute(sql: "PRAGMA query_only = 1;")
  }

  /// Allows changes to be written to the database.
  ///
  /// See <https://www.sqlite.org/pragma.html#pragma_query_only> for more information.
  public func endReadOnly() throws {
    try execute(sql: "PRAGMA query_only = 0;")
  }

  /// Prevents data changes on database files for the duration of the given block.
  ///
  /// When in read-only mode, any attempt to `CREATE`, `DELETE`, `DROP`, `INSERT`, or `UPDATE`
  /// will result in an `SQLITE_READONLY` error.
  ///
  /// See <https://www.sqlite.org/pragma.html#pragma_query_only> for more information.
  public func readOnly<T>(_ work: @escaping () throws -> T) throws -> T {
    if configuration.readOnly {
      return try work()
    }

    try beginReadOnly()
    return try throwingFirstError {
      try work()
    } finally: {
      try endReadOnly()
    }
  }
}

extension Database: CustomStringConvertible {
  public var description: String {
    String(cString: sqlite3_db_filename(handle, nil))
  }
}

extension Database {
  @discardableResult
  func validate(_ code: SQLiteResultCode) throws -> SQLiteResultCode {
    guard code == SQLITE_OK || code == SQLITE_ROW || code == SQLITE_DONE else {
      throw SQLiteError(code: code)
    }

    return code
  }
}

private func throwingFirstError<T>(execute: () throws -> T, finally: () throws -> Void) throws -> T {
  var result: Result<T, Error>
  do {
    result = .success(try execute())
  } catch {
    result = .failure(error)
  }

  do {
    try finally()
  } catch {
    if case .success = result {
      result = .failure(error)
    }
  }

  switch result {
  case .success(let value):
    return value
  case .failure(let error):
    throw error
  }
}
