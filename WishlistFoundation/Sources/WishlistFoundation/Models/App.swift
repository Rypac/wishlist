import Foundation

public struct App: Identifiable, Equatable {
  public let id: Int
  public var title: String
  public var seller: String
  public var description: String
  public var url: URL
  public var icon: Icon
  public var bundleID: String
  public var releaseDate: Date
  public var price: Tracked<Price>
  public var version: Tracked<Version>
  public let firstAdded: Date
  public var lastViewed: Date?

  public init(
    id: Int,
    title: String,
    seller: String,
    description: String,
    url: URL,
    icon: Icon,
    bundleID: String,
    releaseDate: Date,
    price: Tracked<Price>,
    version: Tracked<Version>,
    firstAdded: Date,
    lastViewed: Date?
  ) {
    self.id = id
    self.title = title
    self.seller = seller
    self.description = description
    self.url = url
    self.icon = icon
    self.bundleID = bundleID
    self.releaseDate = releaseDate
    self.price = price
    self.version = version
    self.firstAdded = firstAdded
    self.lastViewed = lastViewed
  }
}

extension App: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

public extension App {
  mutating func applyUpdate(_ app: App) {
    title = app.title
    seller = app.seller
    description = app.description
    url = app.url
    icon = app.icon
    bundleID = app.bundleID
    releaseDate = app.releaseDate
    price = Tracked(current: app.price.current, previous: price.current)
    version = Tracked(current: app.version.current, previous: version.current)
  }
}
