import Foundation

public struct Version {
  public var name: String
  public var date: Date
  public var notes: String?

  public init(name: String, date: Date, notes: String?) {
    self.name = name
    self.date = date
    self.notes = notes
  }
}

extension Version: Comparable {
  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.date < rhs.date
  }
}
