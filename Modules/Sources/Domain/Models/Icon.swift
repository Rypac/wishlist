import Foundation

public struct Icon: Equatable {
  public var small: URL
  public var medium: URL
  public var large: URL

  public init(small: URL, medium: URL, large: URL) {
    self.small = small
    self.medium = medium
    self.large = large
  }
}
