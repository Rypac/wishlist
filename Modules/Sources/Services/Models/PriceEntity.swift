import CoreData
import Domain

public final class PriceEntity: NSManagedObject {
  @NSManaged var date: Date
  @NSManaged var value: NSDecimalNumber
  @NSManaged var formatted: String
  @NSManaged var app: AppEntity

  static var entityName: String { "PriceEntity" }
}

extension PriceEntity {
  func update(app: AppSnapshot, at date: Date) {
    self.date = date
    self.value = app.price.value as NSDecimalNumber
    self.formatted = app.price.formatted
  }
}
