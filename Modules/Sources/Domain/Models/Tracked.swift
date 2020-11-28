public struct Tracked<T> {
  public let current: T
  public let previous: T?

  public init(current: T, previous: T? = nil) {
    self.current = current
    self.previous = previous
  }
}

extension Tracked: Equatable where T: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.previous == rhs.previous && lhs.current == rhs.current
  }
}
