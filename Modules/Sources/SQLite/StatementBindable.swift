import Foundation
import SQLite3

public protocol StatementBindable {
  @discardableResult
  func bind(to statement: SQLiteStatement, at index: Int32) -> Int32
}

extension Bool: StatementBindable {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
    sqlite3_bind_int64(statement, index, self ? 1 : 0)
  }
}

extension Int: StatementBindable {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
    sqlite3_bind_int64(statement, index, Int64(self))
  }
}

extension Int8: StatementBindable {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
    sqlite3_bind_int64(statement, index, Int64(self))
  }
}

extension Int16: StatementBindable {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
    sqlite3_bind_int64(statement, index, Int64(self))
  }
}

extension Int32: StatementBindable {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
    sqlite3_bind_int64(statement, index, Int64(self))
  }
}

extension Int64: StatementBindable {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
    sqlite3_bind_int64(statement, index, self)
  }
}

extension Float: StatementBindable {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
    sqlite3_bind_double(statement, index, Double(self))
  }
}

extension Double: StatementBindable {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
    sqlite3_bind_double(statement, index, self)
  }
}

extension String: StatementBindable {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
    sqlite3_bind_text(statement, index, self, -1, SQLITE_TRANSIENT)
  }
}

extension URL: StatementBindable {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
    sqlite3_bind_text(statement, index, absoluteString, -1, SQLITE_TRANSIENT)
  }
}

extension UUID: StatementBindable {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
    sqlite3_bind_text(statement, index, uuidString, -1, SQLITE_TRANSIENT)
  }
}

extension Data: StatementBindable {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
    withUnsafeBytes { bytes in
      sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), SQLITE_TRANSIENT)
    }
  }
}

@available(macOS 10.12, *)
extension Date: StatementBindable {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
    let dateString = Date.utcISO8601DateFormatter.string(from: self)
    return sqlite3_bind_text(statement, index, dateString, -1, SQLITE_TRANSIENT)
  }
}

extension Optional: StatementBindable where Wrapped: StatementBindable {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
    if let wrappedValue = self {
      return wrappedValue.bind(to: statement, at: index)
    } else {
      return sqlite3_bind_null(statement, index)
    }
  }
}

extension StatementBindable where Self: RawRepresentable, RawValue: StatementBindable {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
    rawValue.bind(to: statement, at: index)
  }
}
