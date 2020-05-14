import Foundation
import CoreData
import WishlistFoundation

public final class AppEntity: NSManagedObject {
  @NSManaged var id: NSNumber
  @NSManaged var title: String
  @NSManaged var seller: String
  @NSManaged var appDescription: String
  @NSManaged var url: URL
  @NSManaged var iconSmallURL: URL
  @NSManaged var iconMediumURL: URL
  @NSManaged var iconLargeURL: URL
  @NSManaged var bundleID: String
  @NSManaged var releaseDate: Date
  @NSManaged var price: Double
  @NSManaged var formattedPrice: String
  @NSManaged var version: String
  @NSManaged var updateDate: Date
  @NSManaged var releaseNotes: String?
  @NSManaged var versions: Set<VersionEntity>
  @NSManaged var prices: Set<PriceEntity>

  static var entityName: String { "AppEntity" }
}

extension AppEntity {
  func update(app: App) {
    id = NSNumber(value: app.id)
    title = app.title.trimmingCharacters(in: .whitespaces)
    seller = app.seller
    appDescription = app.description.trimmingCharacters(in: .whitespacesAndNewlines)
    url = app.url
    iconSmallURL = app.icon.small
    iconMediumURL = app.icon.medium
    iconLargeURL = app.icon.large
    bundleID = app.bundleID
    releaseDate = app.releaseDate
    price = app.price.value
    formattedPrice = app.price.formatted
    version = app.version
    updateDate = app.updateDate
    releaseNotes = app.releaseNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func add(version: VersionEntity) {
    mutableSetValue(forKey: "versions").add(version)
  }

  func add(price: PriceEntity) {
    mutableSetValue(forKey: "prices").add(price)
  }
}
