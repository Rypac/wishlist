import Foundation

public class DatabasePool: DatabaseWriter {
  private let readerDatabaseConnection: Database
  private let readerDatabaseQueue = DispatchQueue(label: "SQLite.DatbasePool.reader")

  private let writerDatabaseConnection: Database
  private let writerDatabaseQueue = DispatchQueue(label: "SQLite.DatbasePool.writer")

  public init(
    location: DatabaseLocation,
    configuration: DatabaseConfiguration = DatabaseConfiguration()
  ) throws {
    self.writerDatabaseConnection = try Database(location: location, configuration: configuration)

    var readerConfiguration = configuration
    readerConfiguration.readOnly = true
    readerConfiguration.busyMode = .timeout(5)
    self.readerDatabaseConnection = try Database(location: location, configuration: readerConfiguration)

    try writerDatabaseQueue.sync {
      try writerDatabaseConnection.setup()
      if !configuration.readOnly {
        try writerDatabaseConnection.setJournalMode(.wal)
      }
    }
    try readerDatabaseQueue.sync {
      try readerDatabaseConnection.setup()
    }
  }

  // MARK: - DatabaseReader

  @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
  public func read<T>(_ work: (Database) throws -> T) rethrows -> T {
    try readerDatabaseQueue.sync { [readerDatabaseConnection] in
      try work(readerDatabaseConnection)
    }
  }

  public func asyncRead(_ work: @escaping (Result<Database, Error>) -> Void) {
    readerDatabaseQueue.async { [readerDatabaseConnection] in
      work(.success(readerDatabaseConnection))
    }
  }

  // MARK: - DatabaseWriter

  @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
  public func write<T>(_ updates: (Database) throws -> T) rethrows -> T {
    try writerDatabaseQueue.sync { [writerDatabaseConnection] in
      try updates(writerDatabaseConnection)
    }
  }

  public func asyncWrite<T>(
    _ updates: @escaping (Database) throws -> T,
    completion: @escaping (Database, Result<T, Error>) -> Void
  ) {
    writerDatabaseQueue.async { [writerDatabaseConnection] in
      let result = Result {
        try updates(writerDatabaseConnection)
      }

      completion(writerDatabaseConnection, result)
    }
  }
}
