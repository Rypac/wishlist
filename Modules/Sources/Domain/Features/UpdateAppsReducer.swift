import Combine
import ComposableArchitecture
import Foundation

public struct AppUpdateState: Equatable {
  public var apps: [AppDetails]
  public var lastUpdateDate: Date?
  public var updateFrequency: TimeInterval
  public var isUpdateInProgress: Bool

  public init(
    apps: [AppDetails],
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
  case receivedUpdates(Result<[AppSummary], UpdateAppsError>, at: Date)
  case cancelUpdateCheck
}

public struct AppUpdateEnvironment {
  public var lookupApps: ([AppID]) -> AnyPublisher<[AppSummary], Error>

  public init(lookupApps: @escaping ([AppID]) -> AnyPublisher<[AppSummary], Error>) {
    self.lookupApps = lookupApps
  }
}

public let appUpdateReducer = Reducer<AppUpdateState, AppUpdateAction, SystemEnvironment<AppUpdateEnvironment>> { state, action, environment in
  struct CancelUpdatesID: Hashable {}
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
      .cancellable(id: CancelUpdatesID(), cancelInFlight: true)

  case let .receivedUpdates(.success(updatedApps), at: date):
    state.isUpdateInProgress = false
    state.lastUpdateDate = date

    updatedApps.forEach { app in
      if let index = state.apps.firstIndex(where: { $0.id == app.id }) {
        state.apps[index].applyUpdate(app)
      }
    }

    return .none

  case let .receivedUpdates(.failure(error), at: _):
    state.isUpdateInProgress = false
    return .none

  case .cancelUpdateCheck:
    state.isUpdateInProgress = false
    return .cancel(id: CancelUpdatesID())
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

func checkForUpdates(apps: [AppDetails], lookup: ([AppID]) -> AnyPublisher<[AppSummary], Error>) -> AnyPublisher<[AppSummary], Error> {
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

private extension AppSummary {
  func isUpdated(from app: AppDetails) -> Bool {
    if version.date > app.version.date {
      return true
    }

    guard version.date == app.version.date else {
      return false
    }

    return price != app.price.current
      || title != app.title
      || description != app.description
      || icon != app.icon
      || url != app.url
  }
}
