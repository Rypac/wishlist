import BackgroundTasks
import Combine
import ComposableArchitecture

public protocol BackgroundTask: AnyObject {
  var identifier: String { get }
  var expirationHandler: (() -> Void)? { get set }
  func setTaskCompleted(success: Bool)
}

public struct BackgroundTaskConfiguration: Identifiable, Equatable {
  public let id: String
  public var frequency: TimeInterval

  public init(id: String, frequency: TimeInterval) {
    self.id = id
    self.frequency = frequency
  }
}

public struct BackgroundTaskState: Equatable {
  public var updateAppsTask: BackgroundTaskConfiguration

  public init(updateAppsTask: BackgroundTaskConfiguration) {
    self.updateAppsTask = updateAppsTask
  }
}

public enum BackgroundTaskAction {
  case scheduleAppUpdateTask
  case handleAppUpdateTask(BackgroundTask)
  case failedToRegisterTask(BackgroundTaskConfiguration)
}

public struct BackgroundTaskEnvironment {
  public var submitTask: (BGTaskRequest) throws -> Void
  public var fetchApps: () -> [AppSummary]
  public var lookupApps: ([AppID]) -> AnyPublisher<[AppSummary], Error>
  public var saveUpdatedApps: ([AppSummary]) -> Void

  public init(
    submitTask: @escaping (BGTaskRequest) throws -> Void,
    fetchApps: @escaping () -> [AppSummary],
    lookupApps: @escaping ([AppID]) -> AnyPublisher<[AppSummary], Error>,
    saveUpdatedApps: @escaping ([AppSummary]) -> Void
  ) {
    self.submitTask = submitTask
    self.fetchApps = fetchApps
    self.lookupApps = lookupApps
    self.saveUpdatedApps = saveUpdatedApps
  }
}

public let backgroundTaskReducer = Reducer<BackgroundTaskState, BackgroundTaskAction, SystemEnvironment<BackgroundTaskEnvironment>> { state, action, environment in
  switch action {
  case .scheduleAppUpdateTask:
    let task = state.updateAppsTask
    return .fireAndForget {
      let request = BGAppRefreshTaskRequest(identifier: task.id)
      request.earliestBeginDate = environment.now().addingTimeInterval(task.frequency)
      try? environment.submitTask(request)
    }

  case let .handleAppUpdateTask(task):
    return .merge(
      Effect(value: .scheduleAppUpdateTask),
      .run { subscriber in
        let apps = environment.fetchApps()
        let cancellable = checkForUpdates(apps: apps, lookup: environment.lookupApps)
          .sink(
            receiveCompletion: { result in
              if case .finished = result {
                task.setTaskCompleted(success: true)
              } else {
                task.setTaskCompleted(success: false)
              }
              subscriber.send(completion: .finished)
            },
            receiveValue: { newApps in
              environment.saveUpdatedApps(newApps)
            }
          )
        task.expirationHandler = {
          cancellable.cancel()
        }
        return cancellable
      }
    )

  case let .failedToRegisterTask(task):
    return .fireAndForget {
      print("Failed to register task: \(task.id)")
    }
  }
}
