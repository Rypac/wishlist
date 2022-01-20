import Foundation

public struct DatabaseConfiguration {
  public var foreignKeysEnabled = true
  public var readOnly = false
  public var busyMode: BusyMode = .immediateError

  public init() {}
}

public enum TransactionMode: String {
  /// Transaction does not actually start until the database is first accessed.
  case deferred = "DEFERRED"

  /// Starts a new write immediately, without waiting for a write statement.
  case immediate = "IMMEDIATE"

  /// Starts a new write immediately, without waiting for a write statement.
  ///
  /// In journal modes other than WAL, this prevents other database connections from reading
  /// the database while the transaction is underway.
  case exclusive = "EXCLUSIVE"
}

extension TransactionMode: CustomStringConvertible {
  public var description: String { rawValue }
}

public enum JournalMode: String {
  /// Rollback journal is deleted at the conclusion of each transaction.
  case delete = "DELETE"

  /// Commits transactions by truncating the rollback journal to zero-length instead of deleting it.
  ///
  /// On many systems, truncating a file is much faster than deleting the file since the containing
  /// directory does not need to be changed.
  case truncate = "TRUNCATE"

  /// Prevents the rollback journal from being deleted at the end of each transaction and instead,
  /// overwrites to header of the journal with zeros.
  ///
  /// This will prevent other database connections from rolling the journal back. It is useful as an
  /// optimization on platforms where deleting or truncating a file is much more expensive than
  /// overwriting the first block of a file with zeros.
  case persist = "PERSIST"

  /// Stores the rollback journal in volatile RAM.
  ///
  /// This saves disk I/O but at the expense of database safety and integrity. If the application using
  /// SQLite crashes in the middle of a transaction when this journaling mode is set, then the database
  /// file will very likely go corrupt.
  case memory = "MEMORY"

  /// Uses a write-ahead log instead of a rollback journal to implement transactions.
  ///
  /// The WAL journaling mode is persistent; after being set it stays in effect across multiple
  /// database connections and after closing and reopening the database.
  case wal = "WAL"

  /// Disables the rollback journal completely.
  ///
  /// No rollback journal is ever created and hence there is never a rollback journal to delete.
  /// This mode disables the atomic commit and rollback capabilities of SQLite, and usage of the
  /// ROLLBACK command no longer works and acts in an undefined way.
  case off = "OFF"
}

extension JournalMode: CustomStringConvertible {
  public var description: String { rawValue }
}

/// The behaviour when a connection trys to access the database while it is locked by another connection.
///
/// See <https://www.sqlite.org/c3ref/busy_timeout.html> for more information.
public enum BusyMode {
  /// Disable busy handlers and fail immediately with SQLITE_BUSY if the database table is locked.
  case immediateError

  /// Sleeps for a specified time interval when a table is locked.
  ///
  /// If the database is still locked after sleeping for the specified time interval, statement
  /// evaluation steps will fail with SQLITE_BUSY.
  case timeout(TimeInterval)
}
