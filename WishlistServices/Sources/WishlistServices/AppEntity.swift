import Foundation
import CoreData

public final class AppEntity: NSManagedObject {
  @NSManaged var id: NSNumber
  @NSManaged var title: String
  @NSManaged var seller: String
  @NSManaged var appDescription: String
  @NSManaged var url: URL
  @NSManaged var iconURL: URL
  @NSManaged var price: NSNumber
  @NSManaged var formattedPrice: String
  @NSManaged var bundleID: String
  @NSManaged var version: String
  @NSManaged var releaseDate: Date
  @NSManaged var updateDate: Date
  @NSManaged var releaseNotes: String?

  static var entityName: String { "AppEntity" }
}

public extension AppEntity {
  static func fetchRequest(forID id: Int) -> NSFetchRequest<AppEntity> {
    let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
    fetchRequest.predicate = NSPredicate(format: "id = %@", NSNumber(value: id))
    fetchRequest.fetchLimit = 1
    return fetchRequest
  }
}
