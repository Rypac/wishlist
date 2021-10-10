import Foundation

public protocol DatabaseWriter: DatabaseReader {
  func write<T>(_ work: @escaping (Database) throws -> T) throws -> T
  func writeAsync<T>(_ work: @escaping (Database) throws -> T) async throws -> T
}
