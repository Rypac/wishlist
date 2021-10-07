import Foundation
import SQLite3

public protocol DatabaseValueConvertible: StatementBindable {
  var databaseValue: DatabaseValue { get }

  init?(_ databaseValue: DatabaseValue)
}

extension DatabaseValueConvertible {
  public func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
    switch databaseValue.storage {
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

extension Bool: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .init(storage: .integer(self ? 1 : 0)) }

  public init?(_ databaseValue: DatabaseValue) {
    switch databaseValue.storage {
    case .integer(let int64):
      self = int64 == 0
    case .real(let double):
      self = !double.isZero
    default:
      return nil
    }
  }
}

extension Int: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .init(storage: .integer(Int64(self))) }

  public init?(_ databaseValue: DatabaseValue) {
    switch databaseValue.storage {
    case .integer(let int64):
      guard let int = Int(exactly: int64) else {
        return nil
      }

      self = int
    case .real(let double):
      guard let int = Int(exactly: double) else {
        return nil
      }

      self = int
    default:
      return nil
    }
  }
}

extension Int8: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .init(storage: .integer(Int64(self))) }

  public init?(_ databaseValue: DatabaseValue) {
    switch databaseValue.storage {
    case .integer(let int64):
      guard let int8 = Int8(exactly: int64) else {
        return nil
      }

      self = int8
    case .real(let double):
      guard let int8 = Int8(exactly: double) else {
        return nil
      }

      self = int8
    default:
      return nil
    }
  }
}

extension Int16: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .init(storage: .integer(Int64(self))) }

  public init?(_ databaseValue: DatabaseValue) {
    switch databaseValue.storage {
    case .integer(let int64):
      guard let int16 = Int16(exactly: int64) else {
        return nil
      }

      self = int16
    case .real(let double):
      guard let int16 = Int16(exactly: double) else {
        return nil
      }

      self = int16
    default:
      return nil
    }
  }
}

extension Int32: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .init(storage: .integer(Int64(self))) }

  public init?(_ databaseValue: DatabaseValue) {
    switch databaseValue.storage {
    case .integer(let int64):
      guard let int32 = Int32(exactly: int64) else {
        return nil
      }

      self = int32
    case .real(let double):
      guard let int32 = Int32(exactly: double) else {
        return nil
      }

      self = int32
    default:
      return nil
    }
  }
}

extension Int64: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .init(storage: .integer(self)) }

  public init?(_ databaseValue: DatabaseValue) {
    switch databaseValue.storage {
    case .integer(let int64):
      self = int64
    case .real(let double):
      guard let int64 = Int64(exactly: double) else {
        return nil
      }

      self = int64
    default:
      return nil
    }
  }
}

extension Float: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .init(storage: .real(Double(self))) }

  public init?(_ databaseValue: DatabaseValue) {
    switch databaseValue.storage {
    case .integer(let int64):
      self = Float(int64)
    case .real(let double):
      self = Float(double)
    default:
      return nil
    }
  }
}

extension Double: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .init(storage: .real(self)) }

  public init?(_ databaseValue: DatabaseValue) {
    switch databaseValue.storage {
    case .integer(let int64):
      self = Double(int64)
    case .real(let double):
      self = double
    default:
      return nil
    }
  }
}

extension String: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .init(storage: .text(self)) }

  public init?(_ databaseValue: DatabaseValue) {
    switch databaseValue.storage {
    case .text(let string):
      self = string
    case .blob(let data):
      guard let string = String(data: data, encoding: .utf8) else {
        return nil
      }

      self = string
    default:
      return nil
    }
  }
}

extension URL: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .init(storage: .text(absoluteString)) }

  public init?(_ databaseValue: DatabaseValue) {
    guard case .text(let string) = databaseValue.storage, let url = URL(string: string) else {
      return nil
    }

    self = url
  }
}

extension UUID: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .init(storage: .text(uuidString)) }

  public init?(_ databaseValue: DatabaseValue) {
    guard case .text(let string) = databaseValue.storage, let uuid = UUID(uuidString: string) else {
      return nil
    }

    self = uuid
  }
}

extension Data: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { .init(storage: .blob(self)) }

  public init?(_ databaseValue: DatabaseValue) {
    switch databaseValue.storage {
    case .blob(let data):
      self = data
    case .text(let string):
      guard let data = string.data(using: .utf8) else {
        return nil
      }

      self = data
    default:
      return nil
    }
  }
}

@available(macOS 10.12, *)
extension Date: DatabaseValueConvertible {
  static let utcISO8601DateFormatter = ISO8601DateFormatter()

  public var databaseValue: DatabaseValue {
    .init(storage: .text(Date.utcISO8601DateFormatter.string(from: self)))
  }

  public init?(_ databaseValue: DatabaseValue) {
    switch databaseValue.storage {
    case .text(let string):
      guard let date = Date.utcISO8601DateFormatter.date(from: string) else {
        return nil
      }

      self = date
    case .integer(let int64):
      self = Date(timeIntervalSince1970: Double(int64))
    case .real(let double):
      self = Date(timeIntervalSince1970: double)
    default:
      return nil
    }
  }
}

extension DatabaseValueConvertible where Self: RawRepresentable, RawValue: DatabaseValueConvertible {
  public var databaseValue: DatabaseValue { rawValue.databaseValue }

  public init?(_ databaseValue: DatabaseValue) {
    guard let rawValue = RawValue(databaseValue) else {
      return nil
    }

    self.init(rawValue: rawValue)
  }
}
