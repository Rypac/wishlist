import BackgroundTasks

public final class BackgroundDatabaseMaintenance: BackgroundTaskScheduler {
  public let id: String

  private let cleanupDatabase: () async throws -> Void
  private let now: () -> Date

  public init(
    id: String,
    cleanupDatabase: @escaping () async throws -> Void,
    now: @escaping () -> Date
  ) {
    self.id = id
    self.cleanupDatabase = cleanupDatabase
    self.now = now
  }

  public var taskRequest: BGTaskRequest {
    let request = BGProcessingTaskRequest(identifier: id)
    request.requiresExternalPower = false
    request.requiresNetworkConnectivity = false
    return request
  }

  public func run(_ task: BGTask) {
    let cleanupDatabaseTask = Task.detached { [cleanupDatabase] in
      do {
        try await cleanupDatabase()
        task.setTaskCompleted(success: true)
      } catch {
        task.setTaskCompleted(success: false)
      }
    }

    task.expirationHandler = {
      task.setTaskCompleted(success: false)
      cleanupDatabaseTask.cancel()
    }
  }
}
