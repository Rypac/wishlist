import Combine
import ComposableArchitecture
import CoreData
import MobileCoreServices
import UIKit
import WishlistCore
import WishlistFoundation
import WishlistServices

enum Status: Equatable {
  case resting
  case loading([App.ID])
  case success([AppSnapshot])
  case failure
}

struct ExtensionState: Equatable {
  var apps: [App]
  var status: Status

  var addAppsState: AddAppsState {
    get { AddAppsState(apps: apps) }
    set { apps = newValue.apps }
  }
}

enum ExtensionAction {
  case addApps(AddAppsAction)
}

struct ExtensionEnvironment {
  var loadApps: ([App.ID]) -> AnyPublisher<[AppSnapshot], Error>
  var saveApps: ([AppSnapshot]) -> Void
}

let extensionReducer = Reducer<ExtensionState, ExtensionAction, SystemEnvironment<ExtensionEnvironment>>.combine(
  Reducer { state, action, environment in
    switch action {
    case let .addApps(.addApps(ids)):
      state.status = .loading(ids)
      return .none

    case let .addApps(.addAppsResponse(.success(apps))):
      state.status = .success(apps)
      return .fireAndForget {
        environment.saveApps(apps)
      }

    case .addApps(.addAppsResponse(.failure)):
      state.status = .failure
      return .none

    case .addApps:
      return .none
    }
  },
  addAppsReducer.pullback(
    state: \.addAppsState,
    action: /ExtensionAction.addApps,
    environment: { systemEnvironment in
      systemEnvironment.map {
        AddAppsEnvironment(loadApps: $0.loadApps)
      }
    }
  )
)

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

    container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    container.viewContext.automaticallyMergesChangesFromParent = true

    return container
  }()

  private lazy var store: Store<ExtensionState, ExtensionAction> = {
    let appStore = AppStoreService()
    let repository = CoreDataAppRepository(container: persistentContainer)
    let apps = (try? repository.fetchAll()) ?? []
    return Store(
      initialState: ExtensionState(apps: apps, status: .resting),
      reducer: extensionReducer,
      environment: .live(
        environment: ExtensionEnvironment(
          loadApps: appStore.lookup(ids:),
          saveApps: { try? repository.add($0) }
        )
      )
    )
  }()
  private lazy var viewStore: ViewStore<ExtensionState, ExtensionAction> = ViewStore(store)

  private var cancellables = Set<AnyCancellable>()

  @IBOutlet private var statusLabel: UILabel!

  deinit {
    cancellables.forEach { cancellable in
      cancellable.cancel()
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    viewStore.publisher
      .map { state in
        switch state.status {
        case let .loading(ids) where ids.isEmpty:
          return "No apps to add"
        case let .loading(ids):
          return "Adding \(ids.count) apps to Wishlist…"
        case let .success(apps) where apps.isEmpty:
          return "No apps added to Wishlist"
        case let .success(apps):
          return "Added to Wishlist:\n\n" + apps.map(\.title).joined(separator: "\n")
        case .failure:
          return "Failed to add apps to Wishlist"
        case .resting:
          return ""
        }
      }
      .receive(on: DispatchQueue.main)
      .assign(to: \.text, on: statusLabel)
      .store(in: &cancellables)

    viewStore.publisher
      .filter { state in
        guard case .success = state.status else {
          return false
        }
        return true
      }
      .delay(for: .seconds(1.5), scheduler: DispatchQueue.main)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.done()
      }
      .store(in: &cancellables)

    extensionContext!.loadURLs()
      .receive(on: DispatchQueue.main)
      .sink(receiveCompletion: { _ in }) { [weak self] urls in
        self?.viewStore.send(.addApps(.addAppsFromURLs(urls)))
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
