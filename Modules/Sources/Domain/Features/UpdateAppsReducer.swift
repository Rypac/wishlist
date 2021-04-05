import Combine
import ComposableArchitecture
import Foundation
import Toolbox

public struct AppUpdateState: Equatable {
  public var apps: IdentifiedArrayOf<AppDetails>
  public var lastUpdateDate: Date?
  public var updateFrequency: TimeInterval
  public var isUpdateInProgress: Bool

  public init(
    apps: IdentifiedArrayOf<AppDetails>,
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
  public var saveApps: ([AppDetails]) throws -> Void

  public init(
    lookupApps: @escaping ([AppID]) -> AnyPublisher<[AppSummary], Error>,
    saveApps: @escaping ([AppDetails]) throws -> Void
  ) {
    self.lookupApps = lookupApps
    self.saveApps = saveApps
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
    let apps = state.apps.map(\.summary)
    return checkForUpdates(apps: apps, lookup: environment.lookupApps)
      .receive(on: environment.mainQueue())
      .mapError { _ in UpdateAppsError() }
      .catchToEffect()
      .map { .receivedUpdates($0, at: environment.now()) }
      .cancellable(id: CancelUpdatesID(), cancelInFlight: true)

  case let .receivedUpdates(.success(updatedApps), at: date):
    state.isUpdateInProgress = false
    state.lastUpdateDate = date

    for updatedApp in updatedApps {
      state.apps[id: updatedApp.id]?.applyUpdate(updatedApp)
    }

    let updatedAppIds = Set(updatedApps.map(\.id))
    let updatedApps = state.apps.elements.filter { updatedAppIds.contains($0.id) }
    return .fireAndForget {
      try? environment.saveApps(updatedApps)
    }

  case let .receivedUpdates(.failure(error), _):
    state.isUpdateInProgress = false
    return .none

  case .cancelUpdateCheck:
    state.isUpdateInProgress = false
    return .cancel(id: CancelUpdatesID())
  }
}

public final class UpdateChecker {
  public struct Environment {
    public var apps: AnyPublisher<[AppDetails], Never>
    public var lookupApps: ([AppID]) -> AnyPublisher<[AppSummary], Error>
    public var saveApps: ([AppDetails]) throws -> Void
    @UserDefault public var lastUpdateDate: Date?
    public var updateFrequency: TimeInterval

    public init(
      apps: AnyPublisher<[AppDetails], Never>,
      lookupApps: @escaping ([AppID]) -> AnyPublisher<[AppSummary], Error>,
      saveApps: @escaping ([AppDetails]) throws -> Void,
      lastUpdateDate: UserDefault<Date?>,
      updateFrequency: TimeInterval
    ) {
      self.apps = apps
      self.lookupApps = lookupApps
      self.saveApps = saveApps
      self._lastUpdateDate = lastUpdateDate
      self.updateFrequency = updateFrequency
    }
  }

  private var environment: SystemEnvironment<Environment>
  private var cancellable: AnyCancellable?

  public init(environment: SystemEnvironment<Environment>) {
    self.environment = environment
  }

  public func update() {
    guard shouldCheckForUpdates else {
      return
    }

    cancellable = environment.apps
      .first()
      .map { [lookupApps = environment.lookupApps] apps in
        lookupApps(apps.map(\.id))
          .map { latestApps in
            latestApps.reduce(into: [] as [AppDetails]) { updatedApps, latestApp in
              if var app = apps.first(where: { $0.id == latestApp.id }), latestApp.isUpdated(from: app) {
                app.applyUpdate(latestApp)
                updatedApps.append(app)
              }
            }
          }
      }
      .switchToLatest()
      .receive(on: environment.mainQueue())
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { [weak self] updates in
          self?.environment.lastUpdateDate = self?.environment.now()

          if updates.isEmpty {
            return
          }

          do {
            try self?.environment.saveApps(updates)
          } catch {
            print(error)
          }
        }
      )
  }

  private var shouldCheckForUpdates: Bool {
    guard let lastUpdateDate = environment.lastUpdateDate else {
      return true
    }

    return environment.now().timeIntervalSince(lastUpdateDate) >= TimeInterval(environment.updateFrequency)
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

func checkForUpdates(apps: [AppSummary], lookup: ([AppID]) -> AnyPublisher<[AppSummary], Error>) -> AnyPublisher<[AppSummary], Error> {
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
  func isUpdated(from app: AppSummary) -> Bool {
    if version.date > app.version.date {
      return true
    }

    guard version.date == app.version.date else {
      return false
    }

    return price != app.price
      || title != app.title
      || description != app.description
      || icon != app.icon
      || url != app.url
  }

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
