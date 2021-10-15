import Foundation

public struct DatabaseConfiguration {
  public var foreignKeysEnabled = true
  public var readOnly = false
  public var busyMode: BusyMode = .immediateError

  public init() {}
}

public enum TransactionMode: String {
  case deferred = "DEFERRED"
  case exclusive = "EXCLUSIVE"
  case immediate = "IMMEDIATE"
}

extension TransactionMode: CustomStringConvertible {
  public var description: String { rawValue }
}

public enum JournalMode: String {
  case delete = "DELETE"
  case truncate = "TRUNCATE"
  case persist = "PERSIST"
  case memory = "MEMORY"
  case wal = "WAL"
  case off = "OFF"
}

extension JournalMode: CustomStringConvertible {
  public var description: String { rawValue }
}

/// The behaviour when a connection trys to access the database while it is locked by another connection.
///
/// See <https://www.sqlite.org/c3ref/busy_timeout.html> for more information.
public enum BusyMode {
  case immediateError
  case timeout(TimeInterval)
}
