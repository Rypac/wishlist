import Foundation

public struct App: Identifiable, Equatable {
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

  public struct Price: Equatable {
    public let value: Double
    public let formatted: String

    public init(value: Double, formatted: String) {
      self.value = value
      self.formatted = formatted
    }
  }

  public let id: Int
  public let title: String
  public let seller: String
  public let description: String
  public let url: URL
  public let icon: Icon
  public let price: Price
  public let bundleID: String
  public let version: String
  public let releaseDate: Date
  public let updateDate: Date
  public let releaseNotes: String?

  public init(
    id: Int,
    title: String,
    seller: String,
    description: String,
    url: URL,
    icon: Icon,
    price: Price,
    bundleID: String,
    version: String,
    releaseDate: Date,
    updateDate: Date,
    releaseNotes: String?
  ) {
    self.id = id
    self.title = title
    self.seller = seller
    self.description = description
    self.url = url
    self.icon = icon
    self.price = price
    self.bundleID = bundleID
    self.version = version
    self.releaseDate = releaseDate
    self.updateDate = updateDate
    self.releaseNotes = releaseNotes
  }
}
