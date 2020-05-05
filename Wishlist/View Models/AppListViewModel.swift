import Combine
import SwiftUI
import WishlistData

final class AppListViewModel: ObservableObject {
  @Published private(set) var apps: [App]

  private let appRepository: AppRepository
  private let addToWishlistService: AddToWishlistService
  private let settings: SettingsStore

  private var cancellables = Set<AnyCancellable>()

  init(appRepository: AppRepository, addToWishlistService: AddToWishlistService, settings: SettingsStore) {
    self.appRepository = appRepository
    self.addToWishlistService = addToWishlistService
    self.settings = settings

    do {
      self.apps = try appRepository.fetchAll().sorted(by: settings.sortOrder)
    } catch {
      self.apps = []
    }

    let sortOrder = settings.$sortOrder
      .publisher()
      .removeDuplicates()

    Publishers.CombineLatest(appRepository.publisher(), sortOrder)
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
  var sortOrder: SortOrder {
    get { settings.sortOrder }
    set { settings.sortOrder = newValue}
  }

  func addApps(urls: [URL]) {
    addToWishlistService.addApps(urls: urls)
      .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
      .store(in: &cancellables)
  }

  func removeApps(at offsets: IndexSet) {
    var updatedApps = apps
    updatedApps.remove(atOffsets: offsets)

    let appsToRemove = apps.filter { app in
      !updatedApps.contains { $0.id == app.id }
    }
    try? appRepository.delete(appsToRemove)
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
