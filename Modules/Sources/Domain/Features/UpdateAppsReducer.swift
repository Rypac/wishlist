import Combine
import Foundation
import Toolbox

public final class UpdateChecker {
  public struct Environment {
    public var apps: AnyPublisher<[AppDetails], Never>
    public var lookupApps: ([AppID]) -> AnyPublisher<[AppSummary], Error>
    public var saveApps: ([AppDetails]) throws -> Void
    public var system: SystemEnvironment
    @UserDefault public var lastUpdateDate: Date?
    public var updateFrequency: TimeInterval

    public init(
      apps: AnyPublisher<[AppDetails], Never>,
      lookupApps: @escaping ([AppID]) -> AnyPublisher<[AppSummary], Error>,
      saveApps: @escaping ([AppDetails]) throws -> Void,
      system: SystemEnvironment,
      lastUpdateDate: UserDefault<Date?>,
      updateFrequency: TimeInterval
    ) {
      self.apps = apps
      self.lookupApps = lookupApps
      self.saveApps = saveApps
      self.system = system
      self._lastUpdateDate = lastUpdateDate
      self.updateFrequency = updateFrequency
    }
  }

  private var environment: Environment
  private var cancellable: Cancellable?

  public init(environment: Environment) {
    self.environment = environment
  }

  public func update() {
    guard shouldCheckForUpdates else {
      return
    }

    cancellable = environment.apps
      .first()
      .flatMap { [lookupApps = environment.lookupApps] apps in
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
      .receive(on: environment.system.mainQueue)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { [weak self] updates in
          self?.environment.lastUpdateDate = self?.environment.system.now()

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

    let timeSinceLastUpdate = environment.system.now().timeIntervalSince(lastUpdateDate)
    return timeSinceLastUpdate >= TimeInterval(environment.updateFrequency)
  }
}

extension AppSummary {
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
