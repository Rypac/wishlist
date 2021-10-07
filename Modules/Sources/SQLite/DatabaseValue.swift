import Foundation
import SQLite3

public enum SQLiteStorage: Equatable {
  case null
  case integer(Int64)
  case real(Double)
  case text(String)
  case blob(Data)
}

public struct DatabaseValue: Equatable {
  public let storage: SQLiteStorage

  public init(storage: SQLiteStorage) {
    self.storage = storage
  }
}

extension DatabaseValue {
  public static let null = DatabaseValue(storage: .null)

  public var isNull: Bool { storage ~= .null }
}

extension DatabaseValue: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { self }

  public init(_ databaseValue: DatabaseValue) {
    self = databaseValue
  }
}

extension DatabaseValue: StatementConvertible {
  public init(statement: SQLiteStatement, index: Int32) {
    switch sqlite3_column_type(statement, index) {
    case SQLITE_NULL:
      storage = .null
    case SQLITE_INTEGER:
      storage = .integer(sqlite3_column_int64(statement, index))
    case SQLITE_FLOAT:
      storage = .real(sqlite3_column_double(statement, index))
    case SQLITE_TEXT:
      storage = .text(String(cString: sqlite3_column_text(statement, index)))
    case SQLITE_BLOB:
      if let bytes = sqlite3_column_blob(statement, index) {
        storage = .blob(Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, index))))
      } else {
        storage = .blob(Data())
      }
    case let type:
      fatalError("Unexpected SQLite column type: \(type)")
    }
  }
}

extension DatabaseValue: StatementBindable {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
    switch storage {
    case .null:
      return sqlite3_bind_null(statement, index)
    case .integer(let int):
      return sqlite3_bind_int64(statement, index, int)
    case .real(let double):
      return sqlite3_bind_double(statement, index, double)
    case .text(let string):
      return sqlite3_bind_text(statement, index, string, -1, SQLITE_TRANSIENT)
    case .blob(let data):
      return data.withUnsafeBytes { bytes in
        sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), SQLITE_TRANSIENT)
      }
    }
  }
}
