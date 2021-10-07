import Foundation

public struct DatabaseConfiguration {
  public var foreignKeysEnabled = true
  public var readOnly = false
  public var journalMode: JournalMode = .wal
  public var defaultTransactionMode: TransactionMode = .deferred

  public init() {}
}

public enum TransactionMode: String {
  case deferred = "DEFERRED"
  case exclusive = "EXCLUSIVE"
  case immediate = "IMMEDIATE"
}

public enum JournalMode: String {
  case delete = "DELETE"
  case truncate = "TRUNCATE"
  case persist = "PERSIST"
  case memory = "MEMORY"
  case wal = "WAL"
  case off = "OFF"
}
