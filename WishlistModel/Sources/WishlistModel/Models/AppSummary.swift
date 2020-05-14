import Foundation

public struct AppSummary {
  public let id: App.ID
  public var title: String
  public var url: URL
  public var icon: URL
  public var version: String
  public var updateDate: Date
  public var price: Double
  public var formattedPrice: String

  public init(
    id: App.ID,
    title: String,
    url: URL,
    icon: URL,
    version: String,
    updateDate: Date,
    price: Double,
    formattedPrice: String
  ) {
    self.id = id
    self.title = title
    self.url = url
    self.icon = icon
    self.version = version
    self.updateDate = updateDate
    self.price = price
    self.formattedPrice = formattedPrice
  }
}
