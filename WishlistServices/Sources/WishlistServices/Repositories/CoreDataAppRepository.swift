import Combine
import CoreData
import WishlistFoundation
import WishlistData

public class CoreDataAppRepository: AppRepository {
  private let managedContext: NSManagedObjectContext

  public init(context: NSManagedObjectContext) {
    managedContext = context
    managedContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    managedContext.automaticallyMergesChangesFromParent = true
  }

  public func publisher() -> AnyPublisher<[App], Never> {
    NSFetchRequestPublisher(request: AppEntity.fetchAllRequest(), context: managedContext, refresh: .didSaveManagedObjectContextExternally)
      .map { $0.map(App.init) }
      .eraseToAnyPublisher()
  }

  public func fetchAll() throws -> [App] {
    let fetchRequest = AppEntity.fetchAllRequest()
    return try managedContext.fetch(fetchRequest).map(App.init)
  }

  public func fetch(id: App.ID) throws -> App? {
    let fetchRequest = AppEntity.fetchRequest(id: id)
    return try managedContext.fetch(fetchRequest).first.flatMap(App.init)
  }

  public func add(_ app: App) throws {
    managedContext.perform { [managedContext] in
      let entity = AppEntity(context: managedContext)
      entity.update(app: app)
      try? managedContext.saveIfNeeded()
    }
  }

  public func add(_ apps: [App]) throws {
    managedContext.perform { [managedContext] in
      apps.forEach { app in
        let entity = AppEntity(context: managedContext)
        entity.update(app: app)
      }
      do {
        try managedContext.saveIfNeeded()
      } catch {
        print("Failed to add app: \(error)")
      }
    }
  }

  public func update(_ apps: [App]) throws {
    try add(apps)
  }

  public func delete(id: App.ID) throws {
    managedContext.perform { [managedContext] in
      let fetchRequest = AppEntity.fetchRequest(id: id)
      let existingApps = try? managedContext.fetch(fetchRequest)
      guard let existingApp = existingApps?.first else {
        return
      }

      managedContext.delete(existingApp)
      try? managedContext.saveIfNeeded()
    }
  }

  public func delete(ids: [App.ID]) throws {
    managedContext.perform { [managedContext] in
      let ids = ids.map(NSNumber.init)
      let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
      fetchRequest.predicate = NSPredicate(format: "id in %@", ids)

      guard let existingApps = try? managedContext.fetch(fetchRequest), !existingApps.isEmpty else {
        return
      }

      existingApps.forEach { existingApp in
        managedContext.delete(existingApp)
      }
      try? managedContext.saveIfNeeded()
    }
  }
}

private extension NSManagedObjectContext {
  func saveIfNeeded() throws {
    guard hasChanges else {
      return
    }

    try save()
    DarwinNotificationCenter.shared.postNotification(.didSaveManagedObjectContextLocally)
  }
}

private extension AppEntity {
  static func fetchAllRequest() -> NSFetchRequest<AppEntity> {
    let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: "price", ascending: true),
      NSSortDescriptor(key: "title", ascending: true)
    ]
    return fetchRequest
  }

  static func fetchRequest(id: Int) -> NSFetchRequest<AppEntity> {
    let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
    fetchRequest.predicate = NSPredicate(format: "id = %@", NSNumber(value: id))
    fetchRequest.fetchLimit = 1
    return fetchRequest
  }
}

private extension App {
  init(entity: AppEntity) {
    self.init(
      id: entity.id.intValue,
      title: entity.title,
      seller: entity.seller,
      description: entity.appDescription,
      url: entity.url,
      icon: Icon(small: entity.iconSmallURL, medium: entity.iconMediumURL, large: entity.iconLargeURL),
      price: entity.price.doubleValue,
      formattedPrice: entity.formattedPrice,
      bundleID: entity.bundleID,
      version: entity.version,
      releaseDate: entity.releaseDate,
      updateDate: entity.updateDate,
      releaseNotes: entity.releaseNotes
    )
  }
}

private extension AppEntity {
  func update(app: App) {
    id = NSNumber(value: app.id)
    title = app.title.trimmingCharacters(in: .whitespaces)
    seller = app.seller
    appDescription = app.description.trimmingCharacters(in: .whitespacesAndNewlines)
    url = app.url
    iconSmallURL = app.icon.small
    iconMediumURL = app.icon.medium
    iconLargeURL = app.icon.large
    price = NSNumber(value: app.price)
    formattedPrice = app.formattedPrice
    bundleID = app.bundleID
    version = app.version
    releaseDate = app.releaseDate
    updateDate = app.updateDate
    releaseNotes = app.releaseNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
