import SQLite3

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

  public func run<Row: SQLiteDecodable>(_ sql: String, _ bindings: SQLiteEncodable...) throws -> [Row] {
    var statement: SQLiteStatement?
    try validate(sqlite3_prepare_v2(handle, sql, -1, &statement, nil))
    defer { sqlite3_finalize(statement) }

    let encoder = SQLiteBindingEncoder(statement: statement)
    for binding in bindings {
      try encoder.encode(binding)
    }

    var rows: [Row] = []
    while try validate(sqlite3_step(statement)) == SQLITE_ROW {
      let decoder = SQLiteRowDecoder(statement: statement)
      rows.append(try Row(from: decoder))
    }

    return rows
  }

  @discardableResult
  private func validate(_ code: Int32) throws -> Int32 {
    guard code == SQLITE_OK || code == SQLITE_ROW || code == SQLITE_DONE else {
      throw Error(code: code)
    }
    return code
  }

  public struct Error: Swift.Error, Equatable {
    public var code: Int32
    public var description: String
  }
}

private extension Sqlite.Error {
  init(code: Int32) {
    self.code = code
    self.description = String(cString: sqlite3_errstr(code))
  }
}
