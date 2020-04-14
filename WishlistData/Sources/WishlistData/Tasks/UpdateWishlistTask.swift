import BackgroundTasks
import Combine
import Foundation

public final class UpdateWishlistTask {
  private let appRepository: AppRepository
  private let appLookupService: AppLookupService
  private let updateScheduler: UpdateScheduler

  private var cancellables = Set<AnyCancellable>()

  public init(appRepository: AppRepository, appLookupService: AppLookupService, updateScheduler: UpdateScheduler) {
    self.appRepository = appRepository
    self.appLookupService = appLookupService
    self.updateScheduler = updateScheduler
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

  @available(iOS 13.0, *)
  public func performBackgroundUpdate(task: BGAppRefreshTask) {
    let cancellable = updatedApps()
      .sink(receiveCompletion: { _ in task.setTaskCompleted(success: true) }) { [weak self] apps in
        self?.saveUpdatedAppsToWishlist(apps)
      }

    task.expirationHandler = {
      cancellable.cancel()
    }
  }

  private var shouldUpdate: Bool {
    guard let lastUpdateDate = updateScheduler.lastUpdateDate else {
      return true
    }

    let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdateDate)
    return timeSinceLastUpdate > TimeInterval(updateScheduler.updateFrequency)
  }

  private func updatedApps() -> AnyPublisher<[App], Never> {
    guard let apps = try? appRepository.fetchAll(), !apps.isEmpty else {
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

  private func saveUpdatedAppsToWishlist(_ apps: [App]) {
    do {
      if !apps.isEmpty {
        try appRepository.update(apps)
      }
      updateScheduler.lastUpdateDate = Date()
    } catch {
      print("Failed to update apps: \(error)")
    }
  }
}

private extension App {
  func isUpdated(from app: App) -> Bool {
    if updateDate > app.updateDate {
      return true
    }

    guard updateDate == app.updateDate else {
      return false
    }

    return title != app.title
      || description != app.description
      || price != app.price
      || url != app.url
      || icon != app.icon
      || version != app.version
      || releaseNotes != app.releaseNotes
  }
}
