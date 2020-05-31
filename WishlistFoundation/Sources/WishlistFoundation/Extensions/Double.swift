import Foundation

public extension Double {
  func round(toDecimalPlaces places: Int) -> Double {
    let divisor = pow(10.0, Double(places))
    return Foundation.round(self * divisor) / divisor
  }
}
