import Combine
import Foundation
import Toolbox
import UserDefaults

public final class UpdateChecker {
  public struct Environment {
    public var fetchApps: () async throws -> [AppDetails]
    public var lookupApps: ([AppID]) async throws -> [AppSummary]
    public var saveApps: ([AppDetails]) async throws -> Void
    public var system: SystemEnvironment
    @UserDefault public var lastUpdateDate: Date?
    public var updateFrequency: TimeInterval

    public init(
      fetchApps: @escaping () async throws -> [AppDetails],
      lookupApps: @escaping ([AppID]) async throws -> [AppSummary],
      saveApps: @escaping ([AppDetails]) async throws -> Void,
      system: SystemEnvironment,
      lastUpdateDate: UserDefault<Date?>,
      updateFrequency: TimeInterval
    ) {
      self.fetchApps = fetchApps
      self.lookupApps = lookupApps
      self.saveApps = saveApps
      self.system = system
      self._lastUpdateDate = lastUpdateDate
      self.updateFrequency = updateFrequency
    }
  }

  private var environment: Environment
  private var task: Task<Void, Never>?

  public init(environment: Environment) {
    self.environment = environment
  }

  deinit {
    task?.cancel()
  }

  public func updateIfNeeded() async throws {
    if shouldCheckForUpdates {
      try await update()
    }
  }

  public func update() async throws {
    let apps = try await environment.fetchApps()

    let latestApps = try await environment.lookupApps(apps.map(\.id))

    let updatedApps = latestApps.reduce(into: [] as [AppDetails]) { updatedApps, latestApp in
      if var app = apps.first(where: { $0.id == latestApp.id }), latestApp.isUpdated(from: app) {
        app.applyUpdate(latestApp)
        updatedApps.append(app)
      }
    }

    if !updatedApps.isEmpty {
      try await environment.saveApps(updatedApps)
    }

    environment.lastUpdateDate = environment.system.now()
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
