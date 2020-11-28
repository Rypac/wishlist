import Foundation

/// A representation of the latest version of an app as listed in the App Store.
public struct AppSnapshot: Identifiable, Equatable {
  public typealias ID = AppID

  public let id: ID
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
    id: ID,
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