import Combine
import Domain
import MobileCoreServices
import Services
import Toolbox
import UIKit

private enum State: Equatable {
  case resting
  case loading([URL])
  case success([AppSummary])
  case failure
}

private struct Environment {
  var addApps: ([URL]) -> AnyPublisher<Bool, Never>
  var fetchApps: () throws -> [AppDetails]
}

class ActionViewController: UIViewController {
  private let environment: Environment = {
    let path = FileManager.default.storeURL(for: "group.wishlist.database", databaseName: "Wishlist")
    let repository = try! SQLiteAppPersistence(sqlite: SQLite(path: path.absoluteString))
    let appStore = AppStoreService()
    let appAdder = AppAdder(
      environment: .live(AppAdder.Environment(loadApps: appStore.lookup, saveApps: repository.add))
    )
    return Environment(addApps: appAdder.addApps(from:), fetchApps: repository.fetchAll)
  }()

  private let state = CurrentValueSubject<State, Never>(.resting)
  private var cancellables = Set<AnyCancellable>()

  @IBOutlet private var statusLabel: UILabel!

  deinit {
    cancellables.forEach { cancellable in
      cancellable.cancel()
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    state
      .map { state in
        switch state {
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

    state
      .filter { state in
        guard case .success = state else {
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
      .tryMap { [environment] urls -> AnyPublisher<State, Error> in
        let initialApps = Set(try environment.fetchApps().map(\.id))
        return environment.addApps(urls)
          .tryMap { added in
            guard added else {
              return .failure
            }

            let updatedApps = try environment.fetchApps()
            let newApps = updatedApps.filter { !initialApps.contains($0.id) }
            return .success(newApps.map(\.summary))
          }
          .prepend(.loading(urls))
          .eraseToAnyPublisher()
      }
      .switchToLatest()
      .catch { _ in Just(.failure) }
      .subscribe(state)
      .store(in: &cancellables)
  }

  @IBAction func done() {
    extensionContext!.completeRequest(returningItems: extensionContext!.inputItems, completionHandler: nil)
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
      return .just([])
    }

    let loadURLs = providers.map { $0.loadURL() }
    return Publishers.Sequence(sequence: loadURLs)
      .flatMap { $0 }
      .collect()
      .eraseToAnyPublisher()
  }
}
