import Foundation
import Toolbox
import UserDefaults

public final class UpdateChecker {
  private let system: SystemEnvironment
  @UserDefault private var lastUpdateDate: Date?
  private let updateFrequency: TimeInterval
  private let updateTask: SharedTask<Void, Error>

  public init(
    fetchApps: @escaping () async throws -> [AppDetails],
    lookupApps: @escaping ([AppID]) async throws -> [AppSummary],
    saveApps: @escaping ([AppDetails]) async throws -> Void,
    system: SystemEnvironment,
    lastUpdateDate: UserDefault<Date?>,
    updateFrequency: TimeInterval
  ) {
    self.system = system
    self._lastUpdateDate = lastUpdateDate
    self.updateFrequency = updateFrequency

    self.updateTask = SharedTask<Void, Error> {
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

      lastUpdateDate.wrappedValue = system.now()
    }
  }

  public func updateIfNeeded() async throws {
    if shouldCheckForUpdates {
      try await update()
    }
  }

  public func update() async throws {
    try await updateTask.run()
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
