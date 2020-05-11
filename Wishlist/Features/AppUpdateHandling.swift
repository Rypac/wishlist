import Combine
import ComposableArchitecture
import Foundation
import WishlistData

struct AppUpdateState: Equatable {
  var apps: [App]
  var lastUpdateDate: Date?
  var updateFrequency: TimeInterval
  var isUpdateInProgress: Bool = false
}

enum AppUpdateAction {
  case checkForUpdates
  case receivedUpdates([App], at: Date)
}

struct AppUpdateEnvironment {
  var lookupApps: ([App.ID]) -> AnyPublisher<[App], Error>
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var now: () -> Date
}

let appUpdateReducer = Reducer<AppUpdateState, AppUpdateAction, AppUpdateEnvironment> { state, action, environment in
  switch action {
  case .checkForUpdates:
    guard state.shouldCheckForUpdates(now: environment.now()) else {
      return .none
    }

    state.isUpdateInProgress = true
    return checkForUpdates(apps: state.apps, lookup: environment.lookupApps)
      .receive(on: environment.mainQueue)
      .eraseToEffect()
      .map { .receivedUpdates($0, at: environment.now()) }

  case let .receivedUpdates(updatedApps, at: date):
    state.isUpdateInProgress = false
    state.apps.append(contentsOf: updatedApps)
    state.lastUpdateDate = date
    return .none
  }
}

private extension AppUpdateState {
  func shouldCheckForUpdates(now: Date) -> Bool {
    if isUpdateInProgress || apps.isEmpty {
      return false
    }
    guard let lastUpdateDate = lastUpdateDate else {
      return true
    }
    return now.timeIntervalSince(lastUpdateDate) > TimeInterval(updateFrequency)
  }
}

func checkForUpdates(apps: [App], lookup: ([App.ID]) -> AnyPublisher<[App], Error>) -> AnyPublisher<[App], Never> {
  lookup(apps.map(\.id))
    .map { latestApps in
      latestApps.reduce(into: []) { result, latestApp in
        guard let app = apps.first(where: { $0.id == latestApp.id }) else {
          return
        }
        if latestApp.isUpdated(from: app) {
          result.append(latestApp)
        }
      }
    }
    .replaceError(with: [])
    .eraseToAnyPublisher()
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
