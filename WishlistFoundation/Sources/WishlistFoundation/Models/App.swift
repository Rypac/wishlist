import Foundation

public struct App: Identifiable, Equatable {
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

  public struct Price: Equatable {
    public var value: Double
    public var formatted: String

    public init(value: Double, formatted: String) {
      self.value = value
      self.formatted = formatted
    }
  }

  public let id: Int
  public var title: String
  public var seller: String
  public var description: String
  public var url: URL
  public var icon: Icon
  public var price: Price
  public var bundleID: String
  public var version: String
  public var releaseDate: Date
  public var updateDate: Date
  public var releaseNotes: String?

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
