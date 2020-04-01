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

private extension URL {
  private static let appStoreURLRegex = "https?://(?:itunes|apps).apple.com/(\\w+)/.*/id(\\d+)"

  var appID: Int? {
    let matches = absoluteString.matchingStrings(regex: Self.appStoreURLRegex)
    guard matches.count == 1, matches[0].count == 3, let id = Int(matches[0][2]) else {
      return nil
    }
    return id
  }
}

extension AppListViewModel {
  func addApps(urls: [URL]) {
    let ids = urls.compactMap(\.appID)
    if !ids.isEmpty {
      wishlist.addApps(ids: ids)
    }
  }

  func removeApp(_ app: App) {
    wishlist.remove(app: app)
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

private extension String {
  func matchingStrings(regex: String) -> [[String]] {
    guard let regex = try? NSRegularExpression(pattern: regex, options: []) else {
      return []
    }
    let nsString = self as NSString
    let results  = regex.matches(in: self, options: [], range: NSMakeRange(0, nsString.length))
    return results.map { result in
      (0..<result.numberOfRanges).map {
        result.range(at: $0).location != NSNotFound
          ? nsString.substring(with: result.range(at: $0))
          : ""
      }
    }
  }
}
