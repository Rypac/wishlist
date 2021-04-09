import Foundation

public struct Price {
  public let value: Decimal
  public let formatted: String

  public init(value: Decimal, formatted: String) {
    self.value = value
    self.formatted = formatted
  }
}

extension Price {
  public init(value: Int, formatted: String) {
    self.value = Decimal(value)
    self.formatted = formatted
  }

  public init(value: Double, formatted: String) {
    self.value = Decimal(string: String(format: "%.2f", value))!
    self.formatted = formatted
  }
}

extension Price: Comparable {
  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.value < rhs.value
  }
}
