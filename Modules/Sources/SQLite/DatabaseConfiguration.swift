import Foundation

public struct DatabaseConfiguration {
  public var foreignKeysEnabled = true
  public var readOnly = false
  public var journalMode: JournalMode = .wal

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
