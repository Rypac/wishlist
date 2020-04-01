import Foundation
import CoreData
import WishlistShared

public protocol Entity where Self: NSManagedObject {
  static var entityName: String { get }
}

public final class AppEntity: NSManagedObject, Entity {
  @NSManaged var id: NSNumber?
  @NSManaged var title: String?
  @NSManaged var seller: String?
  @NSManaged var appDescription: String?
  @NSManaged var url: URL?
  @NSManaged var iconURL: URL?
  @NSManaged var price: NSNumber?
  @NSManaged var formattedPrice: String?
  @NSManaged var bundleID: String?
  @NSManaged var version: String?
  @NSManaged var releaseDate: Date?
  @NSManaged var updateDate: Date?
  @NSManaged var releaseNotes: String?

  public static var entityName: String { "AppEntity" }
}

private extension AppEntity {
  static func fetchRequest(forID id: Int) -> NSFetchRequest<AppEntity> {
    let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
    fetchRequest.predicate = NSPredicate(format: "id = %@", NSNumber(value: id))
    fetchRequest.fetchLimit = 1
    return fetchRequest
  }
}

public class CoreDataDatabase: Database {
  private let managedContext: NSManagedObjectContext

  public init(context: NSManagedObjectContext) {
    self.managedContext = context
  }

  public func fetchAll() throws -> [App] {
    let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: "price", ascending: true),
      NSSortDescriptor(key: "title", ascending: true)
    ]
    return try managedContext.fetch(fetchRequest).map(App.init)
  }

  public func fetch(id: Int) throws -> App? {
    let fetchRequest = AppEntity.fetchRequest(forID: id)
    let entities = try managedContext.fetch(fetchRequest)
    return entities.first.flatMap(App.init)
  }

  public func add(app: App) throws {
    try upsert(app: app)
    try managedContext.save()
  }

  public func add(apps: [App]) throws {
    try apps.forEach { app in
      try upsert(app: app)
    }
    try managedContext.save()
  }

  public func remove(app: App) throws {
    let fetchRequest = AppEntity.fetchRequest(forID: app.id)

    let existingApps = try managedContext.fetch(fetchRequest)
    if let existingApp = existingApps.first {
      managedContext.delete(existingApp)
      try managedContext.save()
    }
  }

  public func remove(apps: [App]) throws {
    let ids = apps.map { NSNumber(value: $0.id) }
    let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
    fetchRequest.predicate = NSPredicate(format: "id in %@", ids)

    let existingApps = try managedContext.fetch(fetchRequest)
    guard !existingApps.isEmpty else {
      return
    }

    existingApps.forEach { existingApp in
      managedContext.delete(existingApp)
    }
    try managedContext.save()
  }

  private func upsert(app: App) throws {
    let fetchRequest = AppEntity.fetchRequest(forID: app.id)

    let existingApps = try managedContext.fetch(fetchRequest)
    if let existingApp = existingApps.first {
      existingApp.update(app: app)
    } else {
      let entity = AppEntity(context: managedContext)
      entity.update(app: app)
    }
  }
}

private extension App {
  init(entity: AppEntity) {
    self.init(
      id: entity.id!.intValue,
      title: entity.title!,
      seller: entity.seller!,
      description: entity.appDescription!,
      url: entity.url!,
      iconURL: entity.iconURL!,
      price: entity.price!.doubleValue,
      formattedPrice: entity.formattedPrice!,
      bundleID: entity.bundleID!,
      version: entity.version!,
      releaseDate: entity.releaseDate!,
      updateDate: entity.updateDate!,
      releaseNotes: entity.releaseNotes!
    )
  }
}

private extension AppEntity {
  func update(app: App) {
    id = NSNumber(value: app.id)
    title = app.title
    seller = app.seller
    appDescription = app.description
    url = app.url
    iconURL = app.iconURL
    price = NSNumber(value: app.price)
    formattedPrice = app.formattedPrice
    bundleID = app.bundleID
    version = app.version
    releaseDate = app.releaseDate
    updateDate = app.updateDate
    releaseNotes = app.releaseNotes
  }
}
