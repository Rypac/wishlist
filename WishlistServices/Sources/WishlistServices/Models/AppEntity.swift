import Foundation
import CoreData

public final class AppEntity: NSManagedObject {
  @NSManaged var id: NSNumber
  @NSManaged var title: String
  @NSManaged var seller: String
  @NSManaged var appDescription: String
  @NSManaged var url: URL
  @NSManaged var iconSmallURL: URL
  @NSManaged var iconMediumURL: URL
  @NSManaged var iconLargeURL: URL
  @NSManaged var price: NSNumber
  @NSManaged var formattedPrice: String
  @NSManaged var bundleID: String
  @NSManaged var version: String
  @NSManaged var releaseDate: Date
  @NSManaged var updateDate: Date
  @NSManaged var releaseNotes: String?

  static var entityName: String { "AppEntity" }
}
