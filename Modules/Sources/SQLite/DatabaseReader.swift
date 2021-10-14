import Foundation

public protocol DatabaseReader {
  @_disfavoredOverload // SR-15150 Async overloading in protocol implementation fails
  func read<T>(_ work: (Database) throws -> T) throws -> T

  func asyncRead(_ work: @escaping (Result<Database, Error>) -> Void)
}

extension DatabaseReader {
  public func read<T>(_ work: @Sendable @escaping (Database) throws -> T) async throws -> T {
    try await withUnsafeThrowingContinuation { continuation in
      asyncRead { result in
        do {
          try continuation.resume(returning: work(result.get()))
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }
}
