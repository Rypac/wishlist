import Foundation
import CoreData
import WishlistFoundation

public final class AppEntity: NSManagedObject {
  @NSManaged var identifier: NSNumber
  @NSManaged var title: String
  @NSManaged var seller: String
  @NSManaged var storeDescription: String
  @NSManaged var url: URL
  @NSManaged var iconSmallURL: URL
  @NSManaged var iconMediumURL: URL
  @NSManaged var iconLargeURL: URL
  @NSManaged var bundleID: String
  @NSManaged var releaseDate: Date
  @NSManaged var interaction: InteractionEntity
  @NSManaged var currentPrice: PriceEntity
  @NSManaged var previousPrice: PriceEntity?
  @NSManaged var currentVersion: VersionEntity
  @NSManaged var previousVersion: VersionEntity?
  @NSManaged var versions: Set<VersionEntity>
  @NSManaged var prices: Set<PriceEntity>

  static var entityName: String { "AppEntity" }
}

extension AppEntity {
  func update(app: AppSnapshot) {
    identifier = NSNumber(value: app.id.rawValue)
    title = app.title
    seller = app.seller
    storeDescription = app.description
    url = app.url
    iconSmallURL = app.icon.small
    iconMediumURL = app.icon.medium
    iconLargeURL = app.icon.large
    bundleID = app.bundleID
    releaseDate = app.releaseDate
  }

  func add(version: VersionEntity) {
    previousVersion = currentVersion
    currentVersion = version
    mutableSetValue(forKey: "versions").add(version)
  }

  func add(price: PriceEntity) {
    previousPrice = currentPrice
    currentPrice = price
    mutableSetValue(forKey: "prices").add(price)
  }
}
