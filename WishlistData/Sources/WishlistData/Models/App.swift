import Foundation

public struct App: Identifiable {
  public let id: Int
  public let title: String
  public let seller: String
  public let description: String
  public let url: URL
  public let iconURL: URL
  public let price: Double
  public let formattedPrice: String
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
    iconURL: URL,
    price: Double,
    formattedPrice: String,
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
    self.iconURL = iconURL
    self.price = price
    self.formattedPrice = formattedPrice
    self.bundleID = bundleID
    self.version = version
    self.releaseDate = releaseDate
    self.updateDate = updateDate
    self.releaseNotes = releaseNotes
  }
}
