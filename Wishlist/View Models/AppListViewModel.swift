import Combine
import SwiftUI
import WishlistShared

final class AppListViewModel: ObservableObject {
  @Published private(set) var apps: [App] = []

  private let wishlist: Wishlist
  private let settings: SettingsStore

  private var cancellables = Set<AnyCancellable>()

  init(wishlist: Wishlist, settings: SettingsStore) {
    self.wishlist = wishlist
    self.settings = settings

    let sortOrder = settings.$sortOrder
      .publisher(initialValue: .include)
      .removeDuplicates()

    Publishers.CombineLatest(wishlist.apps, sortOrder)
      .map { apps, sortOrder in
        apps.sorted(by: sortOrder)
      }
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
  func addApps(urls: [URL]) {
    let ids = AppStore.extractIDs(from: urls)
    if !ids.isEmpty {
      wishlist.addApps(ids: ids)
    }
  }

  func removeApps(at offsets: IndexSet) {
    var updatedApps = apps
    updatedApps.remove(atOffsets: offsets)

    let appsToRemove = apps.filter { app in
      !updatedApps.contains { $0.id == app.id }
    }
    wishlist.remove(apps: appsToRemove)
  }
}

private extension Array where Element == App {
  func sorted(by order: SortOrder) -> [App] {
    sorted {
      switch order {
      case .title: return $0.title < $1.title
      case .price: return $0.price < $1.price
      case .updated: return $0.updateDate > $1.updateDate
      }
    }
  }
}
