import Foundation
import Combine
import CoreData
import WishlistShared

public class CoreDataDatabase: NSObject, Database, NSFetchedResultsControllerDelegate {
  private let managedContext: NSManagedObjectContext
  private let controller: NSFetchedResultsController<AppEntity>
  private let subject = CurrentValueSubject<[App], Never>([])

  public init(context: NSManagedObjectContext) {
    self.managedContext = context
    self.controller = NSFetchedResultsController(fetchRequest: AppEntity.fetchAllRequest(), managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
    super.init()

    do {
      try controller.performFetch()
      if let entities = controller.fetchedObjects {
        subject.send(entities.map(App.init))
      }
      controller.delegate = self
    } catch {
      fatalError("Failed to fetch entities: \(error)")
    }
  }

  deinit {
    controller.delegate = nil
  }

  public func publisher() -> AnyPublisher<[App], Never> {
    subject.eraseToAnyPublisher()
  }

  public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    if let entities = self.controller.fetchedObjects {
      subject.send(entities.map(App.init))
    }
  }

  public func fetchAll() throws -> [App] {
    let fetchRequest = AppEntity.fetchAllRequest()
    return try managedContext.fetch(fetchRequest).map(App.init)
  }

  public func fetch(id: Int) throws -> App? {
    let fetchRequest = AppEntity.fetchRequest(forID: id)
    return try managedContext.fetch(fetchRequest).first.flatMap(App.init)
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

private extension AppEntity {
  static func fetchAllRequest() -> NSFetchRequest<AppEntity> {
    let fetchRequest = NSFetchRequest<AppEntity>(entityName: AppEntity.entityName)
    fetchRequest.sortDescriptors = [
      NSSortDescriptor(key: "price", ascending: true),
      NSSortDescriptor(key: "title", ascending: true)
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
      iconURL: entity.iconURL,
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
    iconURL = app.iconURL
    price = NSNumber(value: app.price)
    formattedPrice = app.formattedPrice
    bundleID = app.bundleID
    version = app.version
    releaseDate = app.releaseDate
    updateDate = app.updateDate
    releaseNotes = app.releaseNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
