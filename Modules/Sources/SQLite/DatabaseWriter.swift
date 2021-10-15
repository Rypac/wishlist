import Foundation

public protocol DatabaseWriter: DatabaseReader {
  @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
  func write<T>(_ updates: (Database) throws -> T) rethrows -> T

  func asyncWrite<T>(
    _ updates: @escaping (Database) throws -> T,
    completion: @escaping (Database, Result<T, Error>) -> Void
  )
}

extension DatabaseWriter {
  public func write<T>(_ updates: @Sendable @escaping (Database) throws -> T) async throws -> T {
    try await withUnsafeThrowingContinuation { continuation in
      asyncWrite(updates) { _, result in
        continuation.resume(with: result)
      }
    }
  }
}
