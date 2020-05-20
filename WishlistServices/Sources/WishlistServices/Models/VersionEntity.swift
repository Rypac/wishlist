import CoreData
import WishlistFoundation

public final class VersionEntity: NSManagedObject {
  @NSManaged var date: Date
  @NSManaged var version: String
  @NSManaged var notes: String?
  @NSManaged var app: AppEntity

  static var entityName: String { "VersionEntity" }
}

extension VersionEntity {
  func update(app: App) {
    self.date = app.updateDate
    self.version = app.version
    self.notes = app.releaseNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
