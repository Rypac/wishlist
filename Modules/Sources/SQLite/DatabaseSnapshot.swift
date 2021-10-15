import Foundation

public class DatabaseSnapshot: DatabaseReader {
  private let database: Database
  private let dispatchQueue = DispatchQueue(label: "SQLite.DatabaseSnapshot")

  public init(
    location: DatabaseLocation,
    configuration: DatabaseConfiguration = DatabaseConfiguration()
  ) throws {
    var readerConfiguration = configuration
    readerConfiguration.readOnly = true
    self.database = try Database(location: location, configuration: readerConfiguration)
    try dispatchQueue.sync {
      try database.setup()
    }
  }

  // MARK: - DatabaseReader

  @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
  public func read<T>(_ work: (Database) throws -> T) rethrows -> T {
    try dispatchQueue.sync { [database] in
      try work(database)
    }
  }

  public func asyncRead(_ work: @escaping (Result<Database, Error>) -> Void) {
    dispatchQueue.async { [database] in
      work(.success(database))
    }
  }
}
