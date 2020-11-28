import Foundation

public struct AppID: Equatable, Hashable, Codable, RawRepresentable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }
}

extension AppID: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: IntegerLiteralType) {
    rawValue = value
  }
}

extension AppID: CustomStringConvertible {
  public var description: String { "\(rawValue)" }
}
