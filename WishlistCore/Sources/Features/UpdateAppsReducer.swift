import Combine
import ComposableArchitecture
import Foundation
import WishlistFoundation

public struct AppUpdateState: Equatable {
  public var apps: [App]
  public var lastUpdateDate: Date?
  public var updateFrequency: TimeInterval
  public var isUpdateInProgress: Bool

  public init(
    apps: [App],
    lastUpdateDate: Date?,
    updateFrequency: TimeInterval,
    isUpdateInProgress: Bool
  ) {
    self.apps = apps
    self.lastUpdateDate = lastUpdateDate
    self.updateFrequency = updateFrequency
    self.isUpdateInProgress = isUpdateInProgress
  }
}

public struct UpdateAppsError: Error, Equatable {}

public enum AppUpdateAction: Equatable {
  case checkForUpdates
  case receivedUpdates(Result<[App], UpdateAppsError>, at: Date)
}

public struct AppUpdateEnvironment {
  public var lookupApps: ([App.ID]) -> AnyPublisher<[App], Error>

  public init(lookupApps: @escaping ([App.ID]) -> AnyPublisher<[App], Error>) {
    self.lookupApps = lookupApps
  }
}

public let appUpdateReducer = Reducer<AppUpdateState, AppUpdateAction, SystemEnvironment<AppUpdateEnvironment>> { state, action, environment in
  switch action {
  case .checkForUpdates:
    guard state.shouldCheckForUpdates(now: environment.now()) else {
      return .none
    }

    state.isUpdateInProgress = true
    return checkForUpdates(apps: state.apps, lookup: environment.lookupApps)
      .receive(on: environment.mainQueue())
      .mapError { _ in UpdateAppsError() }
      .catchToEffect()
      .map { .receivedUpdates($0, at: environment.now()) }

  case let .receivedUpdates(.success(updatedApps), at: date):
    state.isUpdateInProgress = false
    state.lastUpdateDate = date

    state.apps.removeAll(where: { app in
      updatedApps.contains { $0.id == app.id }
    })
    state.apps.append(contentsOf: updatedApps)

    return .none

  case let .receivedUpdates(.failure(error), at: _):
    state.isUpdateInProgress = false
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
    return now.timeIntervalSince(lastUpdateDate) >= TimeInterval(updateFrequency)
  }
}

func checkForUpdates(apps: [App], lookup: ([App.ID]) -> AnyPublisher<[App], Error>) -> AnyPublisher<[App], Error> {
  lookup(apps.map(\.id))
    .map { latestApps in
      latestApps.reduce(into: []) { updatedApps, latestApp in
        guard let app = apps.first(where: { $0.id == latestApp.id }) else {
          return
        }
        if latestApp.isUpdated(from: app) {
          updatedApps.append(latestApp)
        }
      }
    }
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
