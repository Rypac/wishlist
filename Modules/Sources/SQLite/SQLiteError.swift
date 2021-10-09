import SQLite3

public typealias SQLiteResultCode = Int32

public struct SQLiteError: Error, Equatable {
  public var code: SQLiteResultCode
  public var message: String
}

extension SQLiteError {
  init(code: SQLiteResultCode) {
    self.code = code
    self.message = String(cString: sqlite3_errstr(code))
  }

  init(code: SQLiteResultCode, statement: SQLiteStatement) {
    self.code = code
    self.message = String(cString: sqlite3_errmsg(statement))
  }
}
