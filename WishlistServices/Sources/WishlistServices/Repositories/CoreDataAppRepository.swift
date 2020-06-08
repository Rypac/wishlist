import Combine
import CoreData
import WishlistFoundation

public final class CoreDataAppRepository: AppRepository {
  private let container: NSPersistentContainer

  public init(container: NSPersistentContainer) {
    self.container = container
  }

  public func publisher() -> AnyPublisher<[App], Never> {
    NSFetchRequestPublisher(request: AppEntity.fetchAll(), context: container.viewContext, refresh: .didSaveManagedObjectContextExternally)
      .map { $0.map(App.init) }
      .eraseToAnyPublisher()
  }

  public func updates() -> AnyPublisher<[App], Never> {
    NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
      .compactMap { notification -> [App]? in
        guard let objects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> else {
          return nil
        }

        return objects.compactMap { object in
          switch object {
          case let interaction as InteractionEntity:
            return App(interaction.app)
          case let notification as NotificationEntity:
            return App(notification.app)
          default:
            return nil
          }
        }
      }
      .eraseToAnyPublisher()
  }

  public func fetchAll() throws -> [App] {
    try container.viewContext.performAndFetch(AppEntity.fetchAll()).map(App.init)
  }

  public func fetch(id: App.ID) throws -> App? {
    try container.viewContext.performAndFetch(AppEntity.fetch(id: id)).first.map(App.init)
  }

  public func versionHistory(id: App.ID) throws -> [Version] {
    try container.viewContext.performAndFetch(VersionEntity.fetchAll(id: id)).map(Version.init)
  }

  public func add(_ apps: [AppSnapshot]) throws {
    container.performBackgroundTask { context in
      let ids = apps.map { NSNumber(value: $0.id.rawValue) }
      let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
      fetchRequest.predicate = NSPredicate(format: "identifier in %@", ids)
      fetchRequest.fetchLimit = ids.count

      guard let existingApps = try? context.fetch(fetchRequest) else {
        return
      }

      apps.forEach { app in
        if let existingApp = existingApps.first(where: { $0.identifier.intValue == app.id.rawValue }) {
          try? context.update(existingApp, with: app, at: Date())
        } else {
          context.insert(app, at: Date())
        }
      }

      try? context.saveIfNeeded()
    }
  }

  public func viewedApp(id: App.ID, at date: Date) throws {
    container.performBackgroundTask { context in
      let fetchRequest = NSFetchRequest<InteractionEntity>(entityName: InteractionEntity.entityName)
      fetchRequest.predicate = NSPredicate(format: "app.identifier = %@", NSNumber(value: id.rawValue))
      fetchRequest.fetchLimit = 1

      if let interaction = try? context.fetch(fetchRequest).first {
        interaction.lastViewed = date
        interaction.viewCount += 1
      }

      try? context.saveIfNeeded()
    }
  }

  public func notify(id: App.ID, for notifications: Set<ChangeNotification>) throws {
    container.performBackgroundTask { context in
      let fetchRequest = NSFetchRequest<NotificationEntity>(entityName: NotificationEntity.entityName)
      fetchRequest.predicate = NSPredicate(format: "app.identifier = %@", NSNumber(value: id.rawValue))
      fetchRequest.fetchLimit = 1

      if let notification = try? context.fetch(fetchRequest).first {
        notification.newVersion = notifications.contains(.newVersion)
        notification.priceDrop = notifications.contains(.priceDrop)
      }

      try? context.saveIfNeeded()
    }
  }

  public func delete(ids: [App.ID]) throws {
    container.performBackgroundTask { context in
      let ids = ids.map { NSNumber(value: $0.rawValue) }
      let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
      fetchRequest.predicate = NSPredicate(format: "identifier in %@", ids)
      fetchRequest.fetchLimit = ids.count

      guard let existingApps = try? context.fetch(fetchRequest) else {
        return
      }

      existingApps.forEach { existingApp in
        context.delete(existingApp)
      }

      try? context.saveIfNeeded()
    }
  }
}

// MARK: - Extensions

private extension NSManagedObjectContext {
  func performAndFetch<T>(_ request: NSFetchRequest<T>) throws -> [T] where T: NSFetchRequestResult {
    try performAndWaitThrows {
      try fetch(request)
    }
  }

  func saveIfNeeded() throws {
    guard hasChanges else {
      return
    }

    try performAndWaitThrows {
      try save()
    }

    DarwinNotificationCenter.shared.postNotification(.didSaveManagedObjectContextLocally)
  }

  private func performAndWaitThrows<T>(_ block: () throws -> T) throws -> T {
    var result: Result<T, Error>?
    performAndWait {
      do {
        result = .success(try block())
      } catch {
        result = .failure(error)
      }
    }

    switch result! {
    case let .success(value): return value
    case let .failure(error): throw error
    }
  }
}

// MARK: - Upsert

private extension NSManagedObjectContext {
  func insert(_ app: AppSnapshot, at date: Date) {
    let interaction = InteractionEntity(context: self)
    interaction.firstAdded = date

    let notification = NotificationEntity(context: self)
    notification.priceDrop = app.price > 0

    let currentPrice = PriceEntity(context: self)
    currentPrice.update(app: app, at: date)

    let currentVersion = VersionEntity(context: self)
    currentVersion.update(app: app)

    let appEntity = AppEntity(context: self)
    appEntity.update(app: app)
    appEntity.add(version: currentVersion)
    appEntity.add(price: currentPrice)
    appEntity.interaction = interaction
    appEntity.notification = notification
  }

  func update(_ existingApp: AppEntity, with app: AppSnapshot, at date: Date) throws {
    existingApp.update(app: app)

    let currentVersion = try performAndFetch(VersionEntity.fetchLatest(id: app.id)).first
    if let currentVersion = currentVersion, app.updateDate > currentVersion.date {
      if app.version == currentVersion.version {
        currentVersion.update(app: app)
      } else {
        let latestVersion = VersionEntity(context: self)
        latestVersion.update(app: app)
        existingApp.add(version: latestVersion)
      }
    }

    let currentPrice = try performAndFetch(PriceEntity.fetchLatest(id: app.id)).first
    if let currentPrice = currentPrice, app.price != currentPrice.value {
      let latestPrice = PriceEntity(context: self)
      latestPrice.update(app: app, at: date)
      existingApp.add(price: latestPrice)
    }
  }
}

// MARK: - Fetch Requests

private extension AppEntity {
  static func fetchAll() -> NSFetchRequest<AppEntity> {
    let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
    fetchRequest.relationshipKeyPathsForPrefetching = ["interaction", "notification"]
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: "title", ascending: true)
    ]
    return fetchRequest
  }

  static func fetch(id: App.ID) -> NSFetchRequest<AppEntity> {
    let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
    fetchRequest.predicate = NSPredicate(format: "identifier = %@", NSNumber(value: id.rawValue))
    fetchRequest.relationshipKeyPathsForPrefetching = ["interaction", "notification"]
    fetchRequest.fetchLimit = 1
    return fetchRequest
  }
}

private extension VersionEntity {
  static func fetchAll(id: App.ID) -> NSFetchRequest<VersionEntity> {
    let fetchRequest = NSFetchRequest<VersionEntity>(entityName: VersionEntity.entityName)
    fetchRequest.predicate = NSPredicate(format: "app.identifier = %@", NSNumber(value: id.rawValue))
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: "date", ascending: false)
    ]
    return fetchRequest
  }

  static func fetchLatest(id: App.ID) -> NSFetchRequest<VersionEntity> {
    let fetchRequest = NSFetchRequest<VersionEntity>(entityName: VersionEntity.entityName)
    fetchRequest.predicate = NSPredicate(format: "app.identifier = %@", NSNumber(value: id.rawValue))
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: "date", ascending: false)
    ]
    fetchRequest.fetchLimit = 1
    return fetchRequest
  }
}

private extension PriceEntity {
  static func fetchAll(id: App.ID) -> NSFetchRequest<PriceEntity> {
    let fetchRequest = NSFetchRequest<PriceEntity>(entityName: PriceEntity.entityName)
    fetchRequest.predicate = NSPredicate(format: "app.identifier = %@", NSNumber(value: id.rawValue))
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: "date", ascending: false)
    ]
    return fetchRequest
  }

  static func fetchLatest(id: App.ID) -> NSFetchRequest<PriceEntity> {
    let fetchRequest = NSFetchRequest<PriceEntity>(entityName: PriceEntity.entityName)
    fetchRequest.predicate = NSPredicate(format: "app.identifier = %@", NSNumber(value: id.rawValue))
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: "date", ascending: false)
    ]
    fetchRequest.fetchLimit = 1
    return fetchRequest
  }
}

private extension App {
  init(_ entity: AppEntity) {
    self.init(
      id: AppID(rawValue: entity.identifier.intValue),
      title: entity.title,
      seller: entity.seller,
      description: entity.storeDescription,
      url: entity.url,
      icon: Icon(small: entity.iconSmallURL, medium: entity.iconMediumURL, large: entity.iconLargeURL),
      bundleID: entity.bundleID,
      releaseDate: entity.releaseDate,
      price: Tracked(entity),
      version: Version(entity),
      firstAdded: entity.interaction?.firstAdded,
      lastViewed: entity.interaction?.lastViewed,
      notifications: entity.notification?.enabled ?? []
    )
  }
}

private extension Version {
  init(_ entity: VersionEntity) {
    self.init(name: entity.version, date: entity.date, notes: entity.releaseNotes)
  }

  init(_ entity: AppEntity) {
    self.init(name: entity.version, date: entity.updateDate, notes: entity.releaseNotes)
  }
}

private extension Price {
  init(_ entity: PriceEntity) {
    self.init(value: entity.value, formatted: entity.formatted)
  }
}

private extension Tracked where T == Price {
  init(_ entity: AppEntity) {
    let previousPrice: Price?
    if let value = entity.previousPrice, let formatted = entity.previousPriceFormatted {
      previousPrice = Price(value: value.doubleValue, formatted: formatted)
    } else {
      previousPrice = nil
    }

    self.init(
      current: Price(value: entity.currentPrice.doubleValue, formatted: entity.currentPriceFormatted),
      previous: previousPrice
    )
  }
}

private extension NotificationEntity {
  var enabled: Set<ChangeNotification> {
    var notifications = Set<ChangeNotification>()
    if priceDrop {
      notifications.insert(.priceDrop)
    }
    if newVersion {
      notifications.insert(.newVersion)
    }
    return notifications
  }
}
