import Foundation

public protocol DatabaseReader {
  func read<T>(_ work: @escaping (Database) throws -> T) throws -> T
  func readAsync<T>(_ work: @escaping (Database) throws -> T) async throws -> T
}
