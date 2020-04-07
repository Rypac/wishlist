import Foundation
import Combine
import CoreData
import WishlistShared

public class WishlistDatabase: NSObject, Database, NSFetchedResultsControllerDelegate {
  private let managedContext: NSManagedObjectContext
  private let controller: NSFetchedResultsController<AppEntity>
  private let subject: CurrentValueSubject<[App], Never>

  private var cancellables = Set<AnyCancellable>()

  public init(context: NSManagedObjectContext) {
    managedContext = context
    managedContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    managedContext.automaticallyMergesChangesFromParent = true
    controller = NSFetchedResultsController(fetchRequest: AppEntity.fetchAllRequest(), managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)

    do {
      try controller.performFetch()
    } catch {
      fatalError("Failed to fetch entities: \(error)")
    }

    if let entities = controller.fetchedObjects {
      subject = CurrentValueSubject(entities.map(App.init))
    } else {
      subject = CurrentValueSubject([])
    }

    super.init()
    controller.delegate = self

    DarwinNotificationCenter.shared.publisher(for: .didSaveManagedObjectContextExternally)
      .receive(on: DispatchQueue.main)
      .sink { [controller, subject] in
        do {
          try controller.performFetch()
          if let entities = controller.fetchedObjects {
            subject.send(entities.map(App.init))
          }
        } catch {
          print("Failed to synchonize: \(error)")
        }
      }
      .store(in: &cancellables)
  }

  deinit {
    controller.delegate = nil
    cancellables.forEach { cancellable in
      cancellable.cancel()
    }
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
    managedContext.perform { [managedContext] in
      let entity = AppEntity(context: managedContext)
      entity.update(app: app)
      try? managedContext.saveIfNeeded()
    }
  }

  public func add(apps: [App]) throws {
    managedContext.perform { [managedContext] in
      apps.forEach { app in
        let entity = AppEntity(context: managedContext)
        entity.update(app: app)
      }
      try? managedContext.saveIfNeeded()
    }
  }

  public func remove(app: App) throws {
    managedContext.perform { [managedContext] in
      let fetchRequest = AppEntity.fetchRequest(forID: app.id)
      let existingApps = try? managedContext.fetch(fetchRequest)
      guard let existingApp = existingApps?.first else {
        return
      }

      managedContext.delete(existingApp)
      try? managedContext.saveIfNeeded()
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
    try managedContext.saveIfNeeded()
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
