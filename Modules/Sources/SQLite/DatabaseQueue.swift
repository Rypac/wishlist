import Foundation

public final class DatabaseQueue: DatabaseWriter {
  private let database: Database
  private let dispatchQueue = DispatchQueue(label: "Wishlist.SQLite")

  public init(_ database: Database) {
    self.database = database
  }

  public func read<T>(_ work: @escaping (Database) throws -> T) throws -> T {
    try dispatchQueue.sync { [database] in
      try database.readOnly {
        try work(database)
      }
    }
  }

  public func readAsync<T>(_ work: @escaping (Database) throws -> T) async throws -> T {
    try await dispatchQueue.asyncAwait { [database] in
      try database.readOnly {
        try work(database)
      }
    }
  }

  public func write<T>(_ work: @escaping (Database) throws -> T) throws -> T {
    try dispatchQueue.sync { [database = database] in
      try work(database)
    }
  }

  public func writeAsync<T>(_ work: @escaping (Database) throws -> T) async throws -> T {
    try await dispatchQueue.asyncAwait { [database] in
      try work(database)
    }
  }
}

private extension DispatchQueue {
  func asyncAwait<T>(
    group: DispatchGroup? = nil,
    qos: DispatchQoS = .unspecified,
    flags: DispatchWorkItemFlags = [],
    execute work: @escaping () throws -> T
  ) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
      self.async(group: group, qos: qos, flags: flags) {
        do {
          continuation.resume(returning: try work())
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }
}
