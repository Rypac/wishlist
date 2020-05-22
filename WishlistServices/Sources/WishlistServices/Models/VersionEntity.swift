import CoreData
import WishlistFoundation

public final class VersionEntity: NSManagedObject {
  @NSManaged var date: Date
  @NSManaged var version: String
  @NSManaged var releaseNotes: String?
  @NSManaged var app: AppEntity
  @NSManaged var currentVersionOfApp: AppEntity?
  @NSManaged var previousVersionOfApp: AppEntity?

  static var entityName: String { "VersionEntity" }
}

extension VersionEntity {
  func update(app: App) {
    self.date = app.version.current.date
    self.version = app.version.current.name
    self.releaseNotes = app.version.current.notes
  }
}
