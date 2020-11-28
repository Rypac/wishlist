import CoreData
import Domain

public final class VersionEntity: NSManagedObject {
  @NSManaged var date: Date
  @NSManaged var version: String
  @NSManaged var releaseNotes: String?
  @NSManaged var app: AppEntity

  static var entityName: String { "VersionEntity" }
}

extension VersionEntity {
  func update(app: AppSnapshot) {
    self.date = app.updateDate
    self.version = app.version
    self.releaseNotes = app.releaseNotes
  }
}