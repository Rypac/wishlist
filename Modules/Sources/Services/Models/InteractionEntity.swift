import CoreData
import Domain

public final class InteractionEntity: NSManagedObject {
  @NSManaged var firstAdded: Date
  @NSManaged var lastViewed: Date?
  @NSManaged var viewCount: Int
  @NSManaged var app: AppEntity

  static var entityName: String { "InteractionEntity" }
}
