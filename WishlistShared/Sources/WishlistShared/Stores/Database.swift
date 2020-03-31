public protocol Database {
  func read() throws -> [App]
  func write(apps: [App]) throws
}
