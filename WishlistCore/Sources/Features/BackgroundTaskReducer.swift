import BackgroundTasks
import Combine
import ComposableArchitecture
import WishlistModel

public struct BackgroundTask: Identifiable, Equatable {
  public let id: String
  public var frequency: TimeInterval

  public init(id: String, frequency: TimeInterval) {
    self.id = id
    self.frequency = frequency
  }
}

public struct BackgroundTaskState: Equatable {
  public var updateAppsTask: BackgroundTask

  public init(updateAppsTask: BackgroundTask) {
    self.updateAppsTask = updateAppsTask
  }
}

public enum BackgroundTaskAction {
  case registerTasks
  case scheduleAppUpdateTask
  case handleAppUpdateTask(BGAppRefreshTask)
  case failedToRegisterTask(BackgroundTask)
}

public struct BackgroundTaskEnvironment {
  public var registerTask: (BackgroundTask) -> AnyPublisher<BGTask, Error>
  public var submitTask: (BGTaskRequest) throws -> Void
  public var fetchApps: () -> [App]
  public var lookupApps: ([App.ID]) -> AnyPublisher<[App], Error>
  public var saveUpdatedApps: ([App]) -> Void

  public init(
    registerTask: @escaping (BackgroundTask) -> AnyPublisher<BGTask, Error>,
    submitTask: @escaping (BGTaskRequest) throws -> Void,
    fetchApps: @escaping () -> [App],
    lookupApps: @escaping ([App.ID]) -> AnyPublisher<[App], Error>,
    saveUpdatedApps: @escaping ([App]) -> Void
  ) {
    self.registerTask = registerTask
    self.submitTask = submitTask
    self.fetchApps = fetchApps
    self.lookupApps = lookupApps
    self.saveUpdatedApps = saveUpdatedApps
  }
}

public let backgroundTaskReducer = Reducer<BackgroundTaskState, BackgroundTaskAction, SystemEnvironment<BackgroundTaskEnvironment>> { state, action, environment in
  switch action {
  case .registerTasks:
    let updateAppsTask = state.updateAppsTask
    return environment.registerTask(updateAppsTask)
      .map { .handleAppUpdateTask($0 as! BGAppRefreshTask) }
      .catch { _ in Just(.failedToRegisterTask(updateAppsTask)) }
      .eraseToEffect()

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
      .async { _ in
        let apps = environment.fetchApps()
        let cancellable = checkForUpdates(apps: apps, lookup: environment.lookupApps)
          .sink(receiveCompletion: { _ in }) { newApps in
            environment.saveUpdatedApps(newApps)
          }
        task.expirationHandler = {
          cancellable.cancel()
        }
        return cancellable
      }
    )

  case .failedToRegisterTask:
    return .none
  }
}
