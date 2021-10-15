import Foundation
import SQLite3

public protocol SQLiteRowDecodable {
  init(row: Row) throws
}

extension String: SQLiteRowDecodable {
  public init(row: Row) throws {
    self = try row[0]
  }
}
