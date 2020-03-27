import Combine
import SwiftUI

final class AppListViewModel: ObservableObject {
  @Published private(set) var apps: [App] {
    didSet {
      database.write(apps: apps)
    }
  }

  private let database: Database
  private let settings: SettingsStore
  private let appStoreService: AppStoreService
  private var cancellables = Set<AnyCancellable>()

  init(database: Database, settings: SettingsStore, appStoreService: AppStoreService) {
    self.database = database
    self.settings = settings
    self.appStoreService = appStoreService
    self.apps = database.read()

    appStoreService.lookup(ids: apps.map(\.id))
      .map { $0.sorted(by: settings.sortOrder) }
      .receive(on: DispatchQueue.main)
      .sink(receiveCompletion: { error in print("Completion: \(error)") }) { [unowned self] apps in
        self.apps = apps
      }
      .store(in: &cancellables)

    settings.$sortOrder.publisher
      .removeDuplicates()
      .map { database.read().sorted(by: $0) }
      .receive(on: DispatchQueue.main)
      .sink { [unowned self] sortedApps in
        self.apps = sortedApps
      }
      .store(in: &cancellables)
  }

  deinit {
    cancellables.forEach { cancellable in
      cancellable.cancel()
    }
  }
}

extension AppListViewModel {
  func removeApp(_ app: App) {
    apps.removeAll { $0.id == app.id }
    database.write(apps: apps)
  }

  func removeApps(at offsets: IndexSet) {
    apps.remove(atOffsets: offsets)
    database.write(apps: apps)
  }
}

private extension Array where Element == App {
  func sorted(by order: SortOrder) -> [App] {
    sorted {
      switch order {
      case .title: return $0.title < $1.title
      case .price: return $0.price < $1.price
      }
    }
  }
}
