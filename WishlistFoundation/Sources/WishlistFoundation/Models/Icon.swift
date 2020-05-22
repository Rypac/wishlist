import Foundation

public struct Icon: Equatable {
  public let small: URL
  public let medium: URL
  public let large: URL

  public init(small: URL, medium: URL, large: URL) {
    self.small = small
    self.medium = medium
    self.large = large
  }
}
