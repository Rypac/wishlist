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
  @NSManaged var interaction: InteractionEntity?
  @NSManaged var notification: NotificationEntity?

  @NSManaged var currentPrice: NSNumber
  @NSManaged var currentPriceFormatted: String
  @NSManaged var previousPrice: NSNumber?
  @NSManaged var previousPriceFormatted: String?

  @NSManaged var version: String
  @NSManaged var updateDate: Date
  @NSManaged var releaseNotes: String?

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
    version = app.version
    updateDate = app.updateDate
    releaseNotes = app.releaseNotes

    if app.price != currentPrice.doubleValue {
      previousPrice = currentPrice
      previousPriceFormatted = currentPriceFormatted
    }
    currentPrice = NSNumber(value: app.price)
    currentPriceFormatted = app.formattedPrice
  }

  func add(version: VersionEntity) {
    mutableSetValue(forKey: "versions").add(version)
  }

  func add(price: PriceEntity) {
    mutableSetValue(forKey: "prices").add(price)
  }
}
