import BackgroundTasks

public protocol BackgroundTaskScheduler {
  var id: String { get }
  var taskRequest: BGTaskRequest { get }
  func run(_ task: BGTask)
}
