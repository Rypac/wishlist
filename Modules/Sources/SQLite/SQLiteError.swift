import Foundation
import SQLite3

public struct SQLiteError: Error, Equatable {
  public var code: Int32
  public var message: String
}

extension SQLiteError {
  init(code: Int32) {
    self.code = code
    self.message = String(cString: sqlite3_errstr(code))
  }

  init(code: Int32, statement: SQLiteStatement) {
    self.code = code
    self.message = String(cString: sqlite3_errmsg(statement))
  }
}
