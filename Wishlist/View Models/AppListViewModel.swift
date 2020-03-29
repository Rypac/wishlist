import Combine
import SwiftUI

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
      case .updated: return $0.updateDate > $1.updateDate
      }
    }
  }
}
