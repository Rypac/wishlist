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
      fetchRequest.predicate = NSPredicate(format: "id in %@", ids)
      fetchRequest.fetchLimit = apps.count

      guard let existingApps = try? managedContext.fetch(fetchRequest) else {
        return
      }

      apps.forEach { [weak self] app in
        if let existingApp = existingApps.first(where: { $0.id.intValue == app.id }) {
          self?.update(existingApp, with: app)
        } else {
          self?.insert(app)
        }
      }

      try? managedContext.saveIfNeeded()
    }
  }

  private func insert(_ app: App) {
    let price = PriceEntity(context: managedContext)
    price.update(app: app, at: Date())

    let version = VersionEntity(context: managedContext)
    version.update(app: app)

    let entity = AppEntity(context: managedContext)
    entity.update(app: app)
    entity.add(version: version)
    entity.add(price: price)
  }

  private func update(_ existingApp: AppEntity, with app: App) {
    existingApp.update(app: app)

    if
      let lastestVersion = try? managedContext.fetch(VersionEntity.fetchLatestVersion(for: app.id)).first,
      lastestVersion.version != app.version
    {
      let newVersion = VersionEntity(context: managedContext)
      newVersion.update(app: app)
      existingApp.add(version: newVersion)
    }

    if
      let latestPrice = try? managedContext.fetch(PriceEntity.fetchLatestPrice(for: app.id)).first,
      latestPrice.value != app.price.value
    {
      let newestPrice = PriceEntity(context: managedContext)
      newestPrice.update(app: app, at: Date())
      existingApp.add(price: newestPrice)
    }
  }

  public func delete(id: App.ID) throws {
    managedContext.perform { [managedContext] in
      let fetchRequest = AppEntity.fetchRequest(id: id)
      guard let existingApp = try? managedContext.fetch(fetchRequest).first else {
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
    fetchRequest.sortDescriptors = [
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

private extension VersionEntity {
  static func fetchLatestVersion(for id: Int) -> NSFetchRequest<VersionEntity> {
    let fetchRequest = NSFetchRequest<VersionEntity>(entityName: VersionEntity.entityName)
    fetchRequest.predicate = NSPredicate(format: "app.id = %@", NSNumber(value: id))
    fetchRequest.fetchLimit = 1
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: "date", ascending: false)
    ]
    return fetchRequest
  }
}

private extension PriceEntity {
  static func fetchLatestPrice(for id: Int) -> NSFetchRequest<PriceEntity> {
    let fetchRequest = NSFetchRequest<PriceEntity>(entityName: PriceEntity.entityName)
    fetchRequest.predicate = NSPredicate(format: "app.id = %@", NSNumber(value: id))
    fetchRequest.fetchLimit = 1
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: "date", ascending: false)
    ]
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
      price: Price(value: entity.price, formatted: entity.formattedPrice),
      bundleID: entity.bundleID,
      version: entity.version,
      releaseDate: entity.releaseDate,
      updateDate: entity.updateDate,
      releaseNotes: entity.releaseNotes
    )
  }
}
