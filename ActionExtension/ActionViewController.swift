import UIKit
import Combine
import CoreData
import MobileCoreServices
import WishlistShared
import WishlistServices

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

  private lazy var database = CoreDataDatabase(context: persistentContainer.viewContext)
  private lazy var wishlist = Wishlist(database: database, appLookupService: AppStoreService())

  private var cancellables = Set<AnyCancellable>()

  @IBOutlet private var statusLabel: UILabel!

  deinit {
    cancellables.forEach { cancellable in
      cancellable.cancel()
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    extensionContext!.loadURLs()
      .map(AppStore.extractIDs)
      .receive(on: DispatchQueue.main)
      .sink(receiveCompletion: { _ in }) { [weak self] ids in
        guard !ids.isEmpty else {
          self?.statusLabel.text = "No apps to add."
          return
        }

        self?.statusLabel.text = "Adding \(ids.count) apps…"
        self?.wishlist.addApps(ids: ids)
        self?.dismissWhenAllAppsHaveBeenAdded(ids: ids)
      }
      .store(in: &cancellables)
  }

  private func dismissWhenAllAppsHaveBeenAdded(ids: [Int]) {
    wishlist.apps
      .receive(on: DispatchQueue.main)
      .sink(receiveCompletion: { _ in }) { [weak self] apps in
        guard !ids.isEmpty else {
          return
        }

        let hasAllIDs = ids.allSatisfy { id in apps.contains { $0.id == id } }
        if hasAllIDs {
          self?.done()
        }
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

    let futureURLs = providers.map { $0.loadURL() }
    return Publishers.Sequence(sequence: futureURLs)
      .flatMap { $0 }
      .collect()
      .eraseToAnyPublisher()
  }
}
