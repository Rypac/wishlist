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
  func update(app: AppSummary) {
    self.date = app.version.date
    self.version = app.version.name
    self.releaseNotes = app.version.notes
  }
}
