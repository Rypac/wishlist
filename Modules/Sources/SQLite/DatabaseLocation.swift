import Foundation

public struct DatabaseLocation: Equatable {
  public var path: String

  public init(path: String) {
    self.path = path
  }
}

extension DatabaseLocation {
  public init(url: URL) {
    self.path = url.path
  }
}

extension DatabaseLocation: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.path = value
  }
}

extension DatabaseLocation: CustomStringConvertible {
  public var description: String { path }
}

extension DatabaseLocation {
  public static let inMemory: DatabaseLocation = ":memory:"
  public static let temporary: DatabaseLocation = ""
}
