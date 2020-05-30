import CoreData
import WishlistFoundation

public final class PriceEntity: NSManagedObject {
  @NSManaged var date: Date
  @NSManaged var value: Double
  @NSManaged var formatted: String
  @NSManaged var app: AppEntity

  static var entityName: String { "PriceEntity" }
}

extension PriceEntity {
  func update(app: AppSnapshot, at date: Date) {
    self.date = date
    self.value = app.price
    self.formatted = app.formattedPrice
  }
}
