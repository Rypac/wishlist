import Combine
import CoreData
import WishlistFoundation

public final class CoreDataAppRepository: AppRepository {
  private let container: NSPersistentContainer

  public init(container: NSPersistentContainer) {
    self.container = container

    let viewContext = container.viewContext
    viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    viewContext.automaticallyMergesChangesFromParent = true
  }

  public func publisher() -> AnyPublisher<[App], Never> {
    NSFetchRequestPublisher(request: AppEntity.fetchAllRequest(), context: container.viewContext, refresh: .didSaveManagedObjectContextExternally)
      .map { $0.map(App.init) }
      .eraseToAnyPublisher()
  }

  public func fetchAll() throws -> [App] {
    let fetchRequest = AppEntity.fetchAllRequest()
    return try container.viewContext.performAndFetch(fetchRequest).map(App.init)
  }

  public func fetch(id: App.ID) throws -> App? {
    let fetchRequest = AppEntity.fetchRequest(id: id)
    return try container.viewContext.performAndFetch(fetchRequest).first.flatMap(App.init)
  }

  public func versionHistory(id: App.ID) throws -> [Version] {
    let fetchRequest = VersionEntity.fetchAll(id: id)
    return try container.viewContext.performAndFetch(fetchRequest).map(Version.init)
  }

  public func add(_ apps: [AppSnapshot]) throws {
    container.performBackgroundTask { context in
      let ids = apps.map { NSNumber(value: $0.id.rawValue) }
      let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
      fetchRequest.predicate = NSPredicate(format: "identifier in %@", ids)
      fetchRequest.relationshipKeyPathsForPrefetching = ["currentPrice", "currentVersion"]
      fetchRequest.fetchLimit = ids.count

      guard let existingApps = try? context.fetch(fetchRequest) else {
        return
      }

      apps.forEach { app in
        if let existingApp = existingApps.first(where: { $0.identifier.intValue == app.id.rawValue }) {
          context.update(existingApp, with: app, at: Date())
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
      try self.fetch(request)
    }
  }

  func saveIfNeeded() throws {
    guard hasChanges else {
      return
    }

    try performAndWaitThrows {
      try self.save()
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

    let currentPrice = PriceEntity(context: self)
    currentPrice.update(app: app, at: date)

    let currentVersion = VersionEntity(context: self)
    currentVersion.update(app: app)

    let appEntity = AppEntity(context: self)
    appEntity.update(app: app)
    appEntity.add(version: currentVersion)
    appEntity.add(price: currentPrice)
    appEntity.interaction = interaction
  }

  func update(_ existingApp: AppEntity, with app: AppSnapshot, at date: Date) {
    existingApp.update(app: app)

    if app.updateDate > existingApp.currentVersion.date {
      let latestVersion = VersionEntity(context: self)
      latestVersion.update(app: app)
      existingApp.add(version: latestVersion)
    }

    if app.price != existingApp.currentPrice.value {
      let latestPrice = PriceEntity(context: self)
      latestPrice.update(app: app, at: date)
      existingApp.add(price: latestPrice)
    }
  }
}

// MARK: - Fetch Requests

private extension AppEntity {
  static func fetchAllRequest() -> NSFetchRequest<AppEntity> {
    let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
    fetchRequest.relationshipKeyPathsForPrefetching = [
      "currentPrice", "previousPrice", "currentVersion", "previousVersion", "interaction"
    ]
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: "title", ascending: true)
    ]
    return fetchRequest
  }

  static func fetchRequest(id: App.ID) -> NSFetchRequest<AppEntity> {
    let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
    fetchRequest.predicate = NSPredicate(format: "identifier = %@", NSNumber(value: id.rawValue))
    fetchRequest.relationshipKeyPathsForPrefetching = [
      "currentPrice", "previousPrice", "currentVersion", "previousVersion"
    ]
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
      price: Tracked(
        current: Price(entity.currentPrice),
        previous: entity.previousPrice.map(Price.init)
      ),
      version: Tracked(
        current: Version(entity.currentVersion),
        previous: entity.previousVersion.map(Version.init)
      ),
      firstAdded: entity.interaction.firstAdded,
      lastViewed: entity.interaction.lastViewed
    )
  }
}

private extension Version {
  init(_ entity: VersionEntity) {
    self.init(name: entity.version, date: entity.date, notes: entity.releaseNotes)
  }
}

private extension Price {
  init(_ entity: PriceEntity) {
    self.init(value: entity.value, formatted: entity.formatted)
  }
}
