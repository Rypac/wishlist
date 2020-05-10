import UIKit
import Combine
import CoreData
import MobileCoreServices
import WishlistData
import WishlistFoundation
import WishlistServices

final class Wishlist {
  let repository: AppRepository
  let lookupService: AppLookupService

  init(repository: AppRepository, lookupService: AppLookupService) {
    self.repository = repository
    self.lookupService = lookupService
  }

  func addApps(ids: [App.ID]) -> AnyPublisher<Void, Error> {
    lookupService.lookup(ids: ids)
      .tryMap { [repository] apps in
        try repository.add(apps)
      }
      .eraseToAnyPublisher()
  }
}

class ActionViewController: UIViewController {

  lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentCloudKitContainer(name: "DataModel")

    let storeURL = FileManager.default.storeURL(for: "group.wishlist.database", databaseName: "Wishlist")
    let cloudStoreDescription = NSPersistentStoreDescription(url: storeURL)
    cloudStoreDescription.configuration = "Cloud"
    cloudStoreDescription.cloudKitContainerOptions =
      NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.org.rypac.Wishlist")
    container.persistentStoreDescriptions = [cloudStoreDescription]

    container.loadPersistentStores() { _, error in
      if let error = error as NSError? {
        fatalError("Unresolved error \(error), \(error.userInfo)")
      }
    }
    return container
  }()

  private lazy var wishlist = Wishlist(repository: CoreDataAppRepository(context: persistentContainer.viewContext), lookupService: AppStoreService())

  private var cancellables = Set<AnyCancellable>()

  @IBOutlet private var statusLabel: UILabel!

  deinit {
    cancellables.forEach { cancellable in
      cancellable.cancel()
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let appIDs = extensionContext!.loadURLs()
      .map(AppStore.extractIDs)
      .buffer(size: 1, prefetch: .keepFull, whenFull: .dropOldest)

    appIDs
      .receive(on: DispatchQueue.main)
      .sink(receiveCompletion: { _ in }) { [weak self] ids in
        if !ids.isEmpty {
          self?.statusLabel.text = "Adding \(ids.count) apps…"
        } else {
          self?.statusLabel.text = "No apps to add."
        }
      }
      .store(in: &cancellables)

    appIDs
      .flatMap { [wishlist] ids in
        wishlist.addApps(ids: ids)
      }
      .receive(on: DispatchQueue.main)
      .sink(receiveCompletion: { _ in }) { [weak self] in
        self?.done()
      }
      .store(in: &cancellables)
  }

  @IBAction func done() {
    self.extensionContext!.completeRequest(returningItems: self.extensionContext!.inputItems, completionHandler: nil)
  }
}

private extension NSExtensionContext {
  var urlItemProviders: [NSItemProvider] {
    guard let items = inputItems as? [NSExtensionItem] else {
      return []
    }

    return items.compactMap(\.attachments)
      .flatMap { $0 }
      .filter { $0.hasItemConformingToTypeIdentifier(kUTTypeURL as String) }
  }

  func loadURLs() -> AnyPublisher<[URL], Error> {
    let providers = urlItemProviders
    if providers.isEmpty {
      return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
    }

    let loadURLs = providers.map { $0.loadURL() }
    return Publishers.Sequence(sequence: loadURLs)
      .flatMap { $0 }
      .collect()
      .eraseToAnyPublisher()
  }
}
