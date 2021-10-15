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
    let flags = configuration.readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE
    let code = sqlite3_open_v2(location.path, &handle, flags | SQLITE_OPEN_NOMUTEX, nil)
    guard code == SQLITE_OK else {
      throw SQLiteError(code: code)
    }
  }

  deinit {
    sqlite3_close_v2(handle)
  }

  func setup() throws {
    if case .timeout(let duration) = configuration.busyMode {
      let milliseconds = Int32(duration * 1000)
      sqlite3_busy_timeout(handle, milliseconds)
    }

    try execute(sql: "PRAGMA foreign_keys = \(configuration.foreignKeysEnabled ? "ON" : "OFF");")
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

  public var version: String {
    get throws {
      let statement = try Statement(self, "SELECT sqlite_version();")
      guard try statement.step() else {
        throw SQLiteError(code: SQLITE_ERROR)
      }

      return try statement.row[0]
    }
  }

  public func setJournalMode(_ mode: JournalMode) throws {
    try execute {
      "PRAGMA journal_mode = \(mode);"
      if case .wal = mode {
        "PRAGMA synchronous = NORMAL;"
      }
    }
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

  /// Interrupt a long-running query.
  ///
  /// This causes any pending database operation to abort and return at its earliest opportunity.
  ///
  /// See <https://www.sqlite.org/c3ref/interrupt.html> for more information.
  public func interrupt() {
    sqlite3_interrupt(handle)
  }
}

// MARK: - Transactions

extension Database {
  /// Manually starts a transaction in the given mode.
  ///
  /// See <https://www.sqlite.org/lang_transaction.html> for more information.
  public func beginTransaction(_ mode: TransactionMode = .deferred) throws {
    try execute(sql: "BEGIN \(mode) TRANSACTION;")
  }

  /// Commits all operations run within the transaction.
  ///
  /// See <https://www.sqlite.org/lang_transaction.html> for more information.
  public func commit() throws {
    try execute(sql: "COMMIT;")
  }

  /// Reverts all operations run within the transaction.
  ///
  /// See <https://www.sqlite.org/lang_transaction.html> for more information.
  public func rollback() throws {
    try execute(sql: "ROLLBACK TRANSACTION;")
  }

  /// Executes the given block in a transaction.
  ///
  /// See <https://www.sqlite.org/lang_transaction.html> for more information.
  public func transaction<T>(_ mode: TransactionMode = .deferred, execute work: () throws -> T) throws -> T {
    try beginTransaction(mode)

    var result: Result<T, Error>
    do {
      result = .success(try work())
      try commit()
    } catch {
      result = .failure(error)
    }

    switch result {
    case .success(let value):
      return value
    case .failure(let error):
      try? rollback()
      throw error
    }
  }
}

// MARK: - Savepoints

extension Database {
  /// Starts a new transaction with the given name.
  ///
  /// See <https://www.sqlite.org/lang_savepoint.html> for more information.
  public func beginSavepoint(_ name: String) throws {
    try execute(literal: "SAVEPOINT \(name);")
  }

  /// Removes all savepoints back to and including the most recent savepoint with a matching name from the transaction stack.
  ///
  /// See <https://www.sqlite.org/lang_savepoint.html> for more information.
  public func releaseSavepoint(_ name: String) throws {
    try execute(literal: "RELEASE SAVEPOINT \(name);")
  }

  /// Reverts the state of the database back to what it was just after the most recent savepoint with a matching name.
  ///
  /// Note that instead of cancelling, this transaction will be restarted and all intervening savepoints will be cancelled.
  ///
  /// See <https://www.sqlite.org/lang_savepoint.html> for more information.
  public func rollbackToSavepoint(_ name: String) throws {
    try execute(literal: "ROLLBACK TO SAVEPOINT \(name);")
  }

  /// Executes the given block in a named savepoint.
  ///
  /// See <https://www.sqlite.org/lang_savepoint.html> for more information.
  public func savepoint<T>(_ name: String, execute work: () throws -> T) throws -> T {
    try beginSavepoint(name)

    var result: Result<T, Error>
    do {
      result = .success(try work())
      try releaseSavepoint(name)
    } catch {
      result = .failure(error)
    }

    switch result {
    case .success(let value):
      return value
    case .failure(let error):
      try? rollbackToSavepoint(name)
      try? releaseSavepoint(name)
      throw error
    }
  }
}

// MARK: - Vacuum

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

// MARK: - Read-only

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
  public func readOnly<T>(_ work: () throws -> T) throws -> T {
    if configuration.readOnly {
      return try work()
    }

    try beginReadOnly()

    var result: Result<T, Error>
    do {
      result = .success(try work())
    } catch {
      result = .failure(error)
    }

    do {
      try endReadOnly()
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
