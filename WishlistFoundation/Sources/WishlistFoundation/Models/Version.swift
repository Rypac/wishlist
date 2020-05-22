import Foundation

public struct Version {
  public let name: String
  public let date: Date
  public let notes: String?

  public init(name: String, date: Date, notes: String?) {
    self.name = name
    self.date = date
    self.notes = notes
  }
}

extension Version: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.date == rhs.date && lhs.name == rhs.name
  }
}

extension Version: Comparable {
  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.date < rhs.date
  }
}
