import Foundation
import SQLite3

public typealias SQLiteStatement = OpaquePointer

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class SQLiteDatabase {
  public private(set) var handle: OpaquePointer? = nil
  private let configuration: DatabaseConfiguration

  public init(
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
    try execute(
      sql: """
        PRAGMA foreign_keys = \(configuration.foreignKeysEnabled ? "ON" : "OFF");
        PRAGMA journal_mode = \(configuration.journalMode.rawValue);
        """
    )
  }

  /// Returns whether the database connection is read-only.
  ///
  /// See <https://www.sqlite.org/c3ref/db_readonly.html> for more information.
  public var readOnly: Bool {
    sqlite3_db_readonly(handle, nil) == 1
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

  public func execute(literal: SQLLiteral) throws {
    if literal.bindings.isEmpty {
      try execute(sql: literal.description)
    } else {
      try execute(sql: literal.description, bindings: literal.bindings)
    }
  }

  public func execute(sql: String, bindings: StatementBindable?...) throws {
    try execute(sql: sql, bindings: bindings)
  }

  public func execute(sql: String, bindings: [StatementBindable?]) throws {
    let statement = try Statement(self, sql).bind(bindings)
    _ = try statement.step()
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
    let statement = try Statement(self, sql).bind(bindings)

    var rows: [Row] = []
    while try statement.step() {
      rows.append(try Row(row: statement.row))
    }

    return rows
  }

  public func transaction(mode: TransactionMode? = nil, execute work: () throws -> Void) throws {
    let transactionMode = mode ?? configuration.defaultTransactionMode
    try execute(sql: "BEGIN \(transactionMode.rawValue) TRANSACTION;")
    do {
      try work()
      try execute(sql: "COMMIT;")
    } catch {
      try execute(sql: "ROLLBACK TRANSACTION;")
      throw error
    }
  }

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
    try execute(sql: "VACUUM INTO ?;", bindings: filePath)
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

extension SQLiteDatabase {
  @discardableResult
  func validate(_ code: SQLiteResultCode) throws -> SQLiteResultCode {
    guard code == SQLITE_OK || code == SQLITE_ROW || code == SQLITE_DONE else {
      throw SQLiteError(code: code)
    }

    return code
  }
}

extension SQLiteDatabase: CustomStringConvertible {
  public var description: String {
    String(cString: sqlite3_db_filename(handle, nil))
  }
}
