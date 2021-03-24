/// Inspired by/copied from https://github.com/pointfreeco/isowords/blob/main/Sources/Sqlite/Sqlite.swift

import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class Sqlite {
  public private(set) var handle: OpaquePointer?

  public init(path: String) throws {
    try validate(
      sqlite3_open_v2(
        path,
        &handle,
        SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE,
        nil
      )
    )
  }

  deinit {
    sqlite3_close_v2(handle)
  }

  public func execute(_ sql: String) throws {
    try validate(sqlite3_exec(handle, sql, nil, nil, nil))
  }

  @discardableResult
  public func run(_ sql: String, _ bindings: Datatype...) throws -> [[Datatype]] {
    var stmt: OpaquePointer?
    try validate(sqlite3_prepare_v2(handle, sql, -1, &stmt, nil))
    defer { sqlite3_finalize(stmt) }
    for (index, binding) in zip(Int32(1)..., bindings) {
      switch binding {
      case .null:
        try validate(sqlite3_bind_null(stmt, index))
      case let .integer(value):
        try validate(sqlite3_bind_int64(stmt, index, value))
      case let .real(value):
        try validate(sqlite3_bind_double(stmt, index, value))
      case let .text(value):
        try validate(sqlite3_bind_text(stmt, index, value, -1, SQLITE_TRANSIENT))
      case let .blob(value):
        try validate(sqlite3_bind_blob(stmt, index, value, -1, SQLITE_TRANSIENT))
      }
    }

    let cols = sqlite3_column_count(stmt)
    var rows: [[Datatype]] = []
    while try validate(sqlite3_step(stmt)) == SQLITE_ROW {
      rows.append(
        try (0..<cols).map { index in
          switch sqlite3_column_type(stmt, index) {
          case SQLITE_NULL:
            return .null
          case SQLITE_INTEGER:
            return .integer(sqlite3_column_int64(stmt, index))
          case SQLITE_FLOAT:
            return .real(sqlite3_column_double(stmt, index))
          case SQLITE_TEXT:
            return .text(String(cString: sqlite3_column_text(stmt, index)))
          case SQLITE_BLOB:
            return .blob(sqlite3_column_blob(stmt, index).load(as: [UInt8].self))
          default:
            throw Error(description: "Invalid data type")
          }
        }
      )
    }

    return rows
  }

  public var lastInsertRowid: Int64 {
    sqlite3_last_insert_rowid(handle)
  }

  @discardableResult
  private func validate(_ code: Int32) throws -> Int32 {
    guard code == SQLITE_OK || code == SQLITE_ROW || code == SQLITE_DONE else {
      throw Error(code: code, db: handle)
    }
    return code
  }

  public enum Datatype: Equatable {
    case blob([UInt8])
    case integer(Int64)
    case null
    case real(Double)
    case text(String)
  }

  public struct Error: Swift.Error, Equatable {
    public var code: Int32?
    public var description: String
  }
}

extension Sqlite.Error {
  init(code: Int32, db: OpaquePointer?) {
    self.code = code
    self.description = String(cString: sqlite3_errstr(code))
  }
}

extension Sqlite.Datatype: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self = .text(value)
  }
}

extension Sqlite.Datatype: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int64) {
    self = .integer(value)
  }
}

extension Sqlite.Datatype: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) {
    self = .integer(value ? 1 : 0)
  }
}

extension Sqlite.Datatype: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) {
    self = .real(value)
  }
}

extension Sqlite.Datatype: ExpressibleByNilLiteral {
  public init(nilLiteral: ()) {
    self = .null
  }
}
