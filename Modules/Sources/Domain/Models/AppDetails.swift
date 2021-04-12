import Foundation

public struct AppDetails: Identifiable, Equatable {
  public typealias ID = AppID

  public let id: ID
  public var title: String
  public var seller: String
  public var description: String
  public var url: URL
  public var icon: Icon
  public var bundleID: String
  public var releaseDate: Date
  public var price: Tracked<Price>
  public var version: Version
  public var firstAdded: Date
  public var lastViewed: Date?

  public init(
    id: ID,
    title: String,
    seller: String,
    description: String,
    url: URL,
    icon: Icon,
    bundleID: String,
    releaseDate: Date,
    price: Tracked<Price>,
    version: Version,
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

extension AppDetails {
  public mutating func applyUpdate(_ app: AppSummary) {
    title = app.title
    seller = app.seller
    description = app.description
    url = app.url
    icon = app.icon
    bundleID = app.bundleID
    releaseDate = app.releaseDate

    if app.price != price.current {
      price = Tracked(
        current: app.price,
        previous: price.current
      )
    }

    if app.version > version {
      // If the update has the same name as the current version, use the previous version instead.
      version = app.version
    }
  }
}

extension AppDetails {
  public var summary: AppSummary {
    AppSummary(
      id: id,
      title: title,
      seller: seller,
      description: description,
      url: url,
      icon: icon,
      price: price.current,
      version: version,
      bundleID: bundleID,
      releaseDate: releaseDate
    )
  }

  public init(
    summary: AppSummary,
    firstAdded: Date,
    lastViewed: Date?
  ) {
    self.init(
      id: summary.id,
      title: summary.title,
      seller: summary.seller,
      description: summary.description,
      url: summary.url,
      icon: summary.icon,
      bundleID: summary.bundleID,
      releaseDate: summary.releaseDate,
      price: Tracked(current: summary.price),
      version: summary.version,
      firstAdded: firstAdded,
      lastViewed: lastViewed
    )
  }
}
