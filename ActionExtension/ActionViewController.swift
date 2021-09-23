import Combine
import Domain
import Services
import Toolbox
import UIKit
import UniformTypeIdentifiers

private enum State: Equatable {
  case resting
  case loading([URL])
  case success([AppSummary])
  case failure
}

private struct Environment {
  var addApps: ([URL]) async throws -> Void
  var fetchApps: () throws -> [AppDetails]
}

class ActionViewController: UIViewController {
  private let environment: Environment = {
    let path = FileManager.default.storeURL(for: "group.wishlist.database", databaseName: "Wishlist")
    let repository = try! SQLiteAppPersistence(sqlite: SQLite(path: path.absoluteString))
    let appStore = AppStoreService()
    let appAdder = AppAdder(
      environment: AppAdder.Environment(
        loadApps: appStore.lookup,
        saveApps: repository.add,
        now: SystemEnvironment.live.now
      )
    )
    return Environment(addApps: appAdder.addApps(from:), fetchApps: repository.fetchAll)
  }()

  private let state = CurrentValueSubject<State, Never>(.resting)
  private var cancellables = Set<AnyCancellable>()
  private var addAppsTask: Task<Void, Never>?

  @IBOutlet private var statusLabel: UILabel!

  deinit {
    for cancellable in cancellables {
      cancellable.cancel()
    }
    addAppsTask?.cancel()
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

    loadURLs()
  }

  private func loadURLs() {
    addAppsTask = Task {
      do {
        let urls = try await extensionContext!.loadURLs()
        state.value = .loading(urls)

        let initialApps = Set(try environment.fetchApps().map(\.id))
        try await environment.addApps(urls)
        let updatedApps = try environment.fetchApps()
        let newApps = updatedApps.filter { !initialApps.contains($0.id) }
        state.value = .success(newApps.map(\.summary))
      } catch {
        state.value = .failure
      }
    }
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
      .filter { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }
  }

  func loadURLs() async throws -> [URL] {
    let providers = urlItemProviders
    switch providers.count {
    case 0: return []
    case 1: return [try await providers[0].loadURL()]
    default:
      var results = Array<URL?>(repeatElement(nil, count: providers.count))
      try await withThrowingTaskGroup(of: (Int, URL).self) { group in
        for (index, provider) in providers.enumerated() {
          group.addTask {
            (index, try await provider.loadURL())
          }
        }
        for try await (index, result) in group {
          results[index] = result
        }
      }
      return results.compactMap { $0 }
    }
  }
}
