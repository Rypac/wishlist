import Foundation
import CoreData

public protocol Entity where Self: NSManagedObject {
  static var entityName: String { get }
}

public final class AppEntity: NSManagedObject, Entity {
  @NSManaged public var id: NSNumber
  @NSManaged public var title: String
  @NSManaged public var seller: String
  @NSManaged public var appDescription: String
  @NSManaged public var url: URL
  @NSManaged public var iconURL: URL
  @NSManaged public var price: NSNumber
  @NSManaged public var formattedPrice: String
  @NSManaged public var bundleID: String
  @NSManaged public var version: String
  @NSManaged public var releaseDate: Date
  @NSManaged public var updateDate: Date
  @NSManaged public var releaseNotes: String?

  public static var entityName: String { "AppEntity" }
}

public extension AppEntity {
  static func fetchRequest(forID id: Int) -> NSFetchRequest<AppEntity> {
    let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
    fetchRequest.predicate = NSPredicate(format: "id = %@", NSNumber(value: id))
    fetchRequest.fetchLimit = 1
    return fetchRequest
  }
}
