import Combine
import Domain
import SQLite
import Services
import Toolbox
import UIKit
import UniformTypeIdentifiers

private enum State {
  case initial
  case loading([URL])
  case success([AppSummary])
  case failure(Error)
}

private struct Environment {
  var addApps: ([URL]) async throws -> Void
  var fetchApps: () async throws -> [AppDetails]
}

class ActionViewController: UIViewController {
  private let environment: Environment = {
    let path = FileManager.default.storeURL(for: "group.watchlist.database", databaseName: "Wishlist")
    let database = try! DatabaseQueue(location: DatabaseLocation(url: path))
    let repository = try! SQLiteAppPersistence(databaseWriter: database)
    let appStore = AppStoreService()
    let appAdder = AppAdder(
      loadApps: appStore.lookup,
      saveApps: repository.add,
      now: SystemEnvironment.live.now
    )
    return Environment(addApps: appAdder.addApps(from:), fetchApps: repository.fetchAll)
  }()

  private let state = CurrentValueSubject<State, Never>(.initial)
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
          "No apps to add"
        case let .loading(ids):
          "Adding \(ids.count) apps to Wishlist…"
        case let .success(apps) where apps.isEmpty:
          "No apps added to Wishlist"
        case let .success(apps):
          "Added to Wishlist:\n\n" + apps.map(\.title).joined(separator: "\n")
        case let .failure(error):
          "Failed to add apps to Wishlist: \(error)"
        case .initial:
          ""
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

        let initialApps = Set(try await environment.fetchApps().map(\.id))
        try await environment.addApps(urls)
        let updatedApps = try await environment.fetchApps()
        let newApps = updatedApps.filter { !initialApps.contains($0.id) }
        state.value = .success(newApps.map(\.summary))
      } catch {
        state.value = .failure(error)
      }
    }
  }

  @IBAction func done() {
    extensionContext!.completeRequest(returningItems: extensionContext!.inputItems, completionHandler: nil)
  }
}

extension NSExtensionContext {
  fileprivate var urlItemProviders: [NSItemProvider] {
    guard let items = inputItems as? [NSExtensionItem] else {
      return []
    }

    return items.compactMap(\.attachments)
      .flatMap { $0 }
      .filter { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }
  }

  fileprivate func loadURLs() async throws -> [URL] {
    let providers = urlItemProviders
    switch providers.count {
    case 0: return []
    case 1: return [try await providers[0].loadURL()]
    default:
      var results = [URL?](repeatElement(nil, count: providers.count))
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
