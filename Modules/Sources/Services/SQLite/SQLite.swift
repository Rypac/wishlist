/// Inspired by/copied from https://github.com/pointfreeco/isowords/blob/main/Sources/Sqlite/Sqlite.swift

import SQLite3

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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

  public func execute(_ sql: String, _ bindings: SQLiteEncodable...) throws {
    var statement: SQLiteStatement?
    try validate(sqlite3_prepare_v2(handle, sql, -1, &statement, nil))
    defer { sqlite3_finalize(statement) }

    let encoder = SQLiteBindingEncoder(statement: statement)
    for binding in bindings {
      try encoder.encode(binding)
    }

    try validate(sqlite3_step(statement))
  }

  @discardableResult
  public func run<Row>(_ sql: String, _ bindings: SQLiteEncodable...) throws -> [Row] where Row: SQLiteRowDecodable {
    var statement: SQLiteStatement?
    try validate(sqlite3_prepare_v2(handle, sql, -1, &statement, nil))
    defer { sqlite3_finalize(statement) }

    let encoder = SQLiteBindingEncoder(statement: statement)
    for binding in bindings {
      try encoder.encode(binding)
    }

    var rows: [Row] = []
    while try validate(sqlite3_step(statement)) == SQLITE_ROW {
      let decoder = SQLiteDecoder(statement: statement)
      rows.append(try Row(from: decoder))
    }

    return rows
  }

  @discardableResult
  private func validate(_ code: Int32) throws -> Int32 {
    guard code == SQLITE_OK || code == SQLITE_ROW || code == SQLITE_DONE else {
      throw Error(code: code, db: handle)
    }
    return code
  }

  public struct Error: Swift.Error, Equatable {
    public var code: Int32
    public var description: String
  }
}

private extension Sqlite.Error {
  init(code: Int32, db: OpaquePointer?) {
    self.code = code
    self.description = String(cString: sqlite3_errstr(code))
  }
}

public enum SQLiteDatatype: Equatable {
  case blob([UInt8])
  case integer(Int64)
  case null
  case real(Double)
  case text(String)
}

extension SQLiteDatatype: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self = .text(value)
  }
}

extension SQLiteDatatype: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int64) {
    self = .integer(value)
  }
}

extension SQLiteDatatype: ExpressibleByBooleanLiteral {
  public init(booleanLiteral value: Bool) {
    self = .integer(value ? 1 : 0)
  }
}

extension SQLiteDatatype: ExpressibleByFloatLiteral {
  public init(floatLiteral value: Double) {
    self = .real(value)
  }
}

extension SQLiteDatatype: ExpressibleByNilLiteral {
  public init(nilLiteral: ()) {
    self = .null
  }
}
