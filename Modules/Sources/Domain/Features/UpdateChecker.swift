import Foundation
import UserDefaults

public final class UpdateChecker {
  private let fetchApps: () async throws -> [AppDetails]
  private let lookupApps: ([AppID]) async throws -> [AppSummary]
  private let saveApps: ([AppDetails]) async throws -> Void
  private let system: SystemEnvironment
  @UserDefault private var lastUpdateDate: Date?
  private let updateFrequency: TimeInterval

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

  public func updateIfNeeded() async throws {
    if shouldCheckForUpdates {
      try await update()
    }
  }

  public func update() async throws {
    let apps = try await fetchApps()

    let latestApps = try await lookupApps(apps.map(\.id))

    let updatedApps = latestApps.reduce(into: [] as [AppDetails]) { updatedApps, latestApp in
      if var app = apps.first(where: { $0.id == latestApp.id }), latestApp.isUpdated(from: app) {
        app.applyUpdate(latestApp)
        updatedApps.append(app)
      }
    }

    if !updatedApps.isEmpty {
      try await saveApps(updatedApps)
    }

    lastUpdateDate = system.now()
  }

  private var shouldCheckForUpdates: Bool {
    guard let lastUpdateDate = lastUpdateDate else {
      return true
    }

    let timeSinceLastUpdate = system.now().timeIntervalSince(lastUpdateDate)
    return timeSinceLastUpdate >= TimeInterval(updateFrequency)
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
