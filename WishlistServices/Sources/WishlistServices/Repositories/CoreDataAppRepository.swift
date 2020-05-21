import Combine
import CoreData
import WishlistFoundation

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

  public func add(_ apps: [App]) throws {
    managedContext.perform { [managedContext] in
      let ids = apps.map { NSNumber(value: $0.id) }
      let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
      fetchRequest.predicate = NSPredicate(format: "identifier in %@", ids)
      fetchRequest.relationshipKeyPathsForPrefetching = ["currentPrice", "currentVersion"]
      fetchRequest.fetchLimit = ids.count

      guard let existingApps = try? managedContext.fetch(fetchRequest) else {
        return
      }

      apps.forEach { [weak self] app in
        if let existingApp = existingApps.first(where: { $0.identifier.intValue == app.id }) {
          self?.update(existingApp, with: app, at: Date())
        } else {
          self?.insert(app, at: Date())
        }
      }

      try? managedContext.saveIfNeeded()
    }
  }

  private func insert(_ app: App, at date: Date) {
    let currentPrice = PriceEntity(context: managedContext)
    currentPrice.update(app: app, at: date)

    let currentVersion = VersionEntity(context: managedContext)
    currentVersion.update(app: app)

    let appEntity = AppEntity(context: managedContext)
    appEntity.update(app: app)
    appEntity.add(version: currentVersion)
    appEntity.add(price: currentPrice)
  }

  private func update(_ existingApp: AppEntity, with app: App, at date: Date) {
    existingApp.update(app: app)

    if app.updateDate > existingApp.currentVersion.date {
      let latestVersion = VersionEntity(context: managedContext)
      latestVersion.update(app: app)
      existingApp.add(version: latestVersion)
    }

    if app.price.value != existingApp.currentPrice.value {
      let latestPrice = PriceEntity(context: managedContext)
      latestPrice.update(app: app, at: date)
      existingApp.add(price: latestPrice)
    }
  }

  public func delete(ids: [App.ID]) throws {
    managedContext.perform { [managedContext] in
      let ids = ids.map(NSNumber.init)
      let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
      fetchRequest.predicate = NSPredicate(format: "identifier in %@", ids)
      fetchRequest.fetchLimit = ids.count

      guard let existingApps = try? managedContext.fetch(fetchRequest) else {
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
    fetchRequest.relationshipKeyPathsForPrefetching = [
      "currentPrice", "previousPrice", "currentVersion", "previousVersion"
    ]
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: "title", ascending: true)
    ]
    return fetchRequest
  }

  static func fetchRequest(id: Int) -> NSFetchRequest<AppEntity> {
    let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
    fetchRequest.predicate = NSPredicate(format: "identifier = %@", NSNumber(value: id))
    fetchRequest.relationshipKeyPathsForPrefetching = [
      "currentPrice", "previousPrice", "currentVersion", "previousVersion"
    ]
    fetchRequest.fetchLimit = 1
    return fetchRequest
  }
}

private extension App {
  init(entity: AppEntity) {
    self.init(
      id: entity.identifier.intValue,
      title: entity.title,
      seller: entity.seller,
      description: entity.storeDescription,
      url: entity.url,
      icon: Icon(small: entity.iconSmallURL, medium: entity.iconMediumURL, large: entity.iconLargeURL),
      price: Price(value: entity.currentPrice.value, formatted: entity.currentPrice.formatted),
      bundleID: entity.bundleID,
      version: entity.currentVersion.version,
      releaseDate: entity.releaseDate,
      updateDate: entity.currentVersion.date,
      releaseNotes: entity.currentVersion.releaseNotes
    )
  }
}
