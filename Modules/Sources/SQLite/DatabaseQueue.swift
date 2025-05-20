import Foundation

public final class DatabaseQueue: DatabaseWriter {
  private let database: Database
  private let dispatchQueue = DispatchQueue(label: "SQLite.DatabaseQueue")

  public init(
    location: DatabaseLocation,
    configuration: DatabaseConfiguration = DatabaseConfiguration()
  ) throws {
    self.database = try Database(location: location, configuration: configuration)
    try dispatchQueue.sync {
      try database.setup()
    }
  }

  // MARK: - DatabaseReader

  @_disfavoredOverload  // SR-15150 Async overloading in protocol implementation fails
  public func read<T>(_ work: (Database) throws -> T) rethrows -> T {
    try dispatchQueue.sync { [database] in
      try database.readOnly {
        try work(database)
      }
    }
  }

  public func asyncRead(_ work: @escaping (Result<Database, Error>) -> Void) {
    dispatchQueue.async { [database] in
      do {
        try database.readOnly {
          work(.success(database))
        }
      } catch {
        work(.failure(error))
      }
    }
  }

  // MARK: - DatabaseWriter

  @_disfavoredOverload  // SR-15150 Async overloading in protocol implementation fails
  public func write<T>(_ updates: (Database) throws -> T) rethrows -> T {
    try dispatchQueue.sync { [database] in
      try updates(database)
    }
  }

  public func asyncWrite<T>(
    _ updates: @escaping (Database) throws -> T,
    completion: @escaping (Database, Result<T, Error>) -> Void
  ) {
    dispatchQueue.async { [database] in
      let result = Result {
        try updates(database)
      }

      completion(database, result)
    }
  }
}
