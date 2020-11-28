import CoreData

public final class NotificationEntity: NSManagedObject {
  @NSManaged var priceDrop: Bool
  @NSManaged var newVersion: Bool
  @NSManaged var app: AppEntity

  static var entityName: String { "NotificationEntity" }
}
