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
  case startUpdate
  case receivedUpdates([App], at: Date)
}

struct AppUpdateEnvironment {
  var lookupApps: ([App.ID]) -> AnyPublisher<[App], Error>
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var now: () -> Date
}

let appUpdateReducer = Reducer<AppUpdateState, AppUpdateAction, AppUpdateEnvironment>.strict { state, action in
  switch action {
  case .checkForUpdates:
    if state.apps.isEmpty {
      return { _ in .none }
    }

    guard let lastUpdateDate = state.lastUpdateDate else {
      return { _ in Effect(value: .startUpdate) }
    }

    let updateFrequency = state.updateFrequency
    return { environment in
      let timeSinceLastUpdate = environment.now().timeIntervalSince(lastUpdateDate)
      guard timeSinceLastUpdate > TimeInterval(updateFrequency) else {
        return .none
      }
      return Effect(value: .startUpdate)
    }

  case .startUpdate:
    let apps = state.apps
    state.isUpdateInProgress = true
    return { environment in
      checkForUpdates(apps: apps, lookup: environment.lookupApps)
        .receive(on: environment.mainQueue)
        .eraseToEffect()
        .map { .receivedUpdates($0, at: environment.now()) }
    }

  case let .receivedUpdates(updatedApps, at: date):
    state.isUpdateInProgress = false
    state.apps.append(contentsOf: updatedApps)
    state.lastUpdateDate = date
    return { _ in .none }
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
