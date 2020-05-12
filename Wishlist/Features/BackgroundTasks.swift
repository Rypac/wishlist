import BackgroundTasks
import Combine
import ComposableArchitecture
import WishlistModel

struct BackgroundTask: Identifiable, Equatable {
  let id: String
  var frequency: TimeInterval
}

struct BackgroundTaskState: Equatable {
  var updateAppsTask: BackgroundTask
}

enum BackgroundTaskAction {
  case registerTasks
  case scheduleAppUpdateTask
  case handleAppUpdateTask(BGAppRefreshTask)
}

struct BackgroundTaskEnvironment {
  var registerTask: (BackgroundTask) -> Effect<BGTask, Never>
  var submitTask: (BGTaskRequest) throws -> Void
  var fetchApps: () -> [App]
  var checkForUpdates: ([App]) -> AnyPublisher<[App], Never>
  var saveUpdatedApps: ([App]) -> Void
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var now: () -> Date
}

let backgroundTaskReducer = Reducer<BackgroundTaskState, BackgroundTaskAction, BackgroundTaskEnvironment> { state, action, environment in
  switch action {
  case .registerTasks:
    return environment.registerTask(state.updateAppsTask)
      .map { .handleAppUpdateTask($0 as! BGAppRefreshTask) }

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
        let cancellable = environment.checkForUpdates(apps)
          .sink(receiveCompletion: { _ in }) { newApps in
            environment.saveUpdatedApps(newApps)
          }
        task.expirationHandler = {
          cancellable.cancel()
        }
        return cancellable
      }
    )
  }
}
