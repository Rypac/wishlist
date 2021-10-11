import BackgroundTasks

public final class BackgroundAppRefresh: BackgroundTaskScheduler {
  public let id: String

  private let frequency: TimeInterval
  private let updateChecker: UpdateChecker
  private let now: () -> Date

  public init(
    id: String,
    frequency: TimeInterval,
    updateChecker: UpdateChecker,
    now: @escaping () -> Date
  ) {
    self.id = id
    self.frequency = frequency
    self.updateChecker = updateChecker
    self.now = now
  }

  public var taskRequest: BGTaskRequest {
    let request = BGAppRefreshTaskRequest(identifier: id)
    request.earliestBeginDate = now().addingTimeInterval(frequency)
    return request
  }

  public func run(_ task: BGTask) {
    let refreshAppsTask = Task.detached { [updateChecker] in
      do {
        try await updateChecker.updateIfNeeded()
        task.setTaskCompleted(success: true)
      } catch {
        task.setTaskCompleted(success: false)
      }
    }

    task.expirationHandler = {
      task.setTaskCompleted(success: false)
      refreshAppsTask.cancel()
    }
  }
}
