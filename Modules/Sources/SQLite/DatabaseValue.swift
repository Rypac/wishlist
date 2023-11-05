import Foundation
import SQLite3

public enum DatabaseValue: Equatable {
  case null
  case integer(Int64)
  case real(Double)
  case text(String)
  case blob(Data)
}

extension DatabaseValue: CustomStringConvertible {
  public var description: String {
    switch self {
    case .null:
      "NULL"
    case .integer(let int64):
      String(int64)
    case .real(let double):
      String(double)
    case .text(let string):
      String(reflecting: string)
    case .blob(let data):
      "Data(\(data.description))"
    }
  }
}

extension DatabaseValue: ExpressibleByNilLiteral {
  public init(nilLiteral: ()) {
    self = .null
  }

  public var isNull: Bool {
    if case .null = self {
      true
    } else {
      false
    }
  }
}

extension DatabaseValue: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) {
    self = .integer(value ? 1 : 0)
  }
}

extension DatabaseValue: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int64) {
    self = .integer(value)
  }
}

extension DatabaseValue: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) {
    self = .real(value)
  }
}

extension DatabaseValue: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self = .text(value)
  }
}

extension DatabaseValue: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { self }

  public init(databaseValue: DatabaseValue) {
    self = databaseValue
  }
}

extension DatabaseValue: StatementConvertible {
  public init(statement: SQLiteStatement, index: Int32) {
    switch sqlite3_column_type(statement, index) {
    case SQLITE_NULL:
      self = .null
    case SQLITE_INTEGER:
      self = .integer(sqlite3_column_int64(statement, index))
    case SQLITE_FLOAT:
      self = .real(sqlite3_column_double(statement, index))
    case SQLITE_TEXT:
      self = .text(String(cString: sqlite3_column_text(statement, index)))
    case SQLITE_BLOB:
      if let bytes = sqlite3_column_blob(statement, index) {
        self = .blob(Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, index))))
      } else {
        self = .blob(Data())
      }
    case let columnType:
      fatalError("Unexpected SQLite column type: \(columnType)")
    }
  }
}

extension DatabaseValue: StatementBindable {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> SQLiteResultCode {
    switch self {
    case .null:
      sqlite3_bind_null(statement, index)
    case .integer(let int):
      sqlite3_bind_int64(statement, index, int)
    case .real(let double):
      sqlite3_bind_double(statement, index, double)
    case .text(let string):
      sqlite3_bind_text(statement, index, string, -1, SQLITE_TRANSIENT)
    case .blob(let data):
      data.withUnsafeBytes { bytes in
        sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), SQLITE_TRANSIENT)
      }
    }
  }
}
