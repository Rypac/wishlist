import BackgroundTasks
import Combine
import Foundation
import UserDefaults

public final class WishlistUpdater {
  private let wishlist: Database
  private let appLookupService: AppLookupService
  private var lastUpdateDate: UserDefault<Date?>

  private var cancellables = Set<AnyCancellable>()

  public init(wishlist: Database, appLookupService: AppLookupService, lastUpdateDate: UserDefault<Date?>) {
    self.wishlist = wishlist
    self.appLookupService = appLookupService
    self.lastUpdateDate = lastUpdateDate
  }

  deinit {
    cancellables.forEach { cancellable in
      cancellable.cancel()
    }
  }

  public func performPeriodicUpdate() {
    guard shouldUpdate else {
      return
    }

    updatedApps()
      .sink(receiveCompletion: { _ in }) { [weak self] apps in
        self?.saveUpdatedAppsToWishlist(apps)
      }
      .store(in: &cancellables)
  }

  public func performBackgroundUpdate(task: BGAppRefreshTask) {
    let cancellable = updatedApps()
      .sink(receiveCompletion: { _ in task.setTaskCompleted(success: true) }) { [weak self] apps in
        self?.saveUpdatedAppsToWishlist(apps)
      }

    task.expirationHandler = {
      cancellable.cancel()
    }
  }
}

private extension WishlistUpdater {
  var shouldUpdate: Bool {
    guard let lastUpdateDate = lastUpdateDate.wrappedValue else {
      return true
    }

    let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdateDate)
    return timeSinceLastUpdate > TimeInterval(5 * 60)
  }

  func updatedApps() -> AnyPublisher<[App], Never> {
    guard let apps = try? wishlist.fetchAll(), !apps.isEmpty else {
      return Just([]).eraseToAnyPublisher()
    }

    return appLookupService.lookup(ids: apps.map(\.id))
      .map { updatedApps in
        updatedApps.reduce(into: []) { result, updatedApp in
          guard let app = apps.first(where: { $0.id == updatedApp.id }) else {
            return
          }
          if updatedApp.isUpdated(from: app) {
            result.append(updatedApp)
          }
        }
      }
      .replaceError(with: [])
      .eraseToAnyPublisher()
  }

  func saveUpdatedAppsToWishlist(_ apps: [App]) {
    do {
      if !apps.isEmpty {
        try wishlist.add(apps: apps)
      }
      lastUpdateDate.wrappedValue = Date()
    } catch {
      print("Failed to update apps: \(error)")
    }
  }
}

private extension App {
  func isUpdated(from app: App) -> Bool {
    updateDate > app.updateDate
      || title != app.title
      || description != app.description
      || price != app.price
      || url != app.url
      || iconURL != app.iconURL
      || version != app.version
      || releaseNotes != app.releaseNotes
  }
}
