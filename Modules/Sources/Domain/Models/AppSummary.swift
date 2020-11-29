import Foundation

/// A representation of the latest version of an app as listed in the App Store.
public struct AppSummary: Identifiable, Equatable {
  public typealias ID = AppID

  public let id: ID
  public var title: String
  public var seller: String
  public var description: String
  public var url: URL
  public var icon: Icon
  public var price: Price
  public var version: Version
  public var bundleID: String
  public var releaseDate: Date

  public init(
    id: ID,
    title: String,
    seller: String,
    description: String,
    url: URL,
    icon: Icon,
    price: Price,
    version: Version,
    bundleID: String,
    releaseDate: Date
  ) {
    self.id = id
    self.title = title
    self.seller = seller
    self.description = description
    self.url = url
    self.icon = icon
    self.price = price
    self.version = version
    self.bundleID = bundleID
    self.releaseDate = releaseDate
  }
}
