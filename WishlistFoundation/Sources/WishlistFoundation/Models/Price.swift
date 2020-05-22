import Foundation

public struct Price {
  public let value: Double
  public let formatted: String

  public init(value: Double, formatted: String) {
    self.value = value
    self.formatted = formatted
  }
}

extension Price: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.value == rhs.value
  }
}

extension Price: Comparable {
  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.value < rhs.value
  }
}
