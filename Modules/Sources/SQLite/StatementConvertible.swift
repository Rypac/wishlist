import Foundation
import SQLite3

public protocol StatementConvertible {
  init?(statement: SQLiteStatement, index: Int32)
}

extension Bool: StatementConvertible {
  public init(statement: SQLiteStatement, index: Int32) {
    self = sqlite3_column_int64(statement, index) != 0
  }
}

extension Int: StatementConvertible {
  public init?(statement: SQLiteStatement, index: Int32) {
    guard let int = Int(exactly: sqlite3_column_int64(statement, index)) else {
      return nil
    }

    self = int
  }
}

extension Int8: StatementConvertible {
  public init?(statement: SQLiteStatement, index: Int32) {
    guard let int8 = Int8(exactly: sqlite3_column_int64(statement, index)) else {
      return nil
    }

    self = int8
  }
}

extension Int16: StatementConvertible {
  public init?(statement: SQLiteStatement, index: Int32) {
    guard let int16 = Int16(exactly: sqlite3_column_int64(statement, index)) else {
      return nil
    }

    self = int16
  }
}

extension Int32: StatementConvertible {
  public init?(statement: SQLiteStatement, index: Int32) {
    guard let int32 = Int32(exactly: sqlite3_column_int64(statement, index)) else {
      return nil
    }

    self = int32
  }
}

extension Int64: StatementConvertible {
  public init(statement: SQLiteStatement, index: Int32) {
    self = sqlite3_column_int64(statement, index)
  }
}

extension Float: StatementConvertible {
  public init?(statement: SQLiteStatement, index: Int32) {
    guard let float = Float(exactly: sqlite3_column_double(statement, index)) else {
      return nil
    }

    self = float
  }
}

extension Double: StatementConvertible {
  public init(statement: SQLiteStatement, index: Int32) {
    self = sqlite3_column_double(statement, index)
  }
}

extension String: StatementConvertible {
  public init(statement: SQLiteStatement, index: Int32) {
    self = String(cString: sqlite3_column_text(statement, index))
  }
}

extension Data: StatementConvertible {
  public init(statement: SQLiteStatement, index: Int32) {
    if let bytes = sqlite3_column_blob(statement, index) {
      self = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, index)))
    } else {
      self = Data()
    }
  }
}

extension StatementConvertible where Self: RawRepresentable, RawValue: StatementConvertible {
  public init?(statement: SQLiteStatement, index: Int32) {
    guard let rawValue = RawValue(statement: statement, index: index) else {
      return nil
    }

    self.init(rawValue: rawValue)
  }
}
