import CoreData
import WishlistFoundation

public final class PriceEntity: NSManagedObject {
  @NSManaged var date: Date
  @NSManaged var value: Double
  @NSManaged var formatted: String

  static var entityName: String { "PriceEntity" }
}

extension PriceEntity {
  func update(app: App, at date: Date) {
    self.date = date
    self.value = app.price.value
    self.formatted = app.price.formatted
  }
}
