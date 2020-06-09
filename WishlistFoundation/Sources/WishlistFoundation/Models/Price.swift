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
    self.value = Decimal(value.truncate(toDecimalPlaces: 2))
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

private extension Double {
  func truncate(toDecimalPlaces places: Int) -> Double {
    let divisor = pow(10.0, Double(places))
    return Foundation.round(self * divisor) / divisor
  }
}
