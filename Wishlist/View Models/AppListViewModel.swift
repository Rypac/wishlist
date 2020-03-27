import Combine
import SwiftUI

final class AppListViewModel: ObservableObject {
  @Published private(set) var apps: [App] = []

  private let wishlist: Wishlist
  private let settings: SettingsStore
  private let appStoreService: AppStoreService
  private var cancellables = Set<AnyCancellable>()

  init(wishlist: Wishlist, settings: SettingsStore, appStoreService: AppStoreService) {
    self.wishlist = wishlist
    self.settings = settings
    self.appStoreService = appStoreService

    wishlist.apps
      .first()
      .setFailureType(to: Error.self)
      .flatMap { apps in
        appStoreService.lookup(ids: apps.map(\.id))
      }
      .sink(receiveCompletion: { _ in }) { [wishlist] apps in
        wishlist.write(apps: apps)
      }
      .store(in: &cancellables)

    let latestSortOrder = settings.$sortOrder.publisher
      .prepend(settings.sortOrder)
      .removeDuplicates()

    Publishers.CombineLatest(wishlist.apps, latestSortOrder)
      .map { apps, sortOrder in
        apps.sorted(by: sortOrder)
      }
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
    var updatedApps = apps
    updatedApps.removeAll { $0.id == app.id }
    wishlist.write(apps: updatedApps)
  }

  func removeApps(at offsets: IndexSet) {
    var updatedApps = apps
    updatedApps.remove(atOffsets: offsets)
    wishlist.write(apps: updatedApps)
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
