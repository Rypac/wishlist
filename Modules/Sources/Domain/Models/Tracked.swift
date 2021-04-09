public struct Tracked<T> {
  public var current: T
  public var previous: T?

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
