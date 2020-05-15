import BackgroundTasks
import Combine
import ComposableArchitecture
import Foundation
import WishlistCore
import WishlistFoundation
import XCTest

class BackgroundTaskReducerTests: XCTestCase {

  let scheduler = DispatchQueue.testScheduler
  let now = Date()
  lazy var systemEnvironment: SystemEnvironment<Void> = {
    .test(
      now: { self.now },
      mainQueue: { self.scheduler.eraseToAnyScheduler() }
    )
  }()

  func testSchedulingUpdateSubmitsTaskWithCorrectIdentifierAndFrequency() throws {
    let taskIdentifier = "refresh-task"
    let taskFrequency = TimeInterval(10)

    var submittedTask: BGTaskRequest?

    let testStore = TestStore(
      initialState: BackgroundTaskState(
        updateAppsTask: BackgroundTaskConfiguration(id: taskIdentifier, frequency: taskFrequency)
      ),
      reducer: backgroundTaskReducer,
      environment: systemEnvironment.map {
        BackgroundTaskEnvironment(
          submitTask: { submittedTask = $0 },
          fetchApps: { [] },
          lookupApps: { _ in
            Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
          },
          saveUpdatedApps: { _ in }
        )
      }
    )

    testStore.assert(
      .send(.scheduleAppUpdateTask),
      .do { self.scheduler.advance(by: 1) },
      .do {
        XCTAssertEqual(submittedTask?.identifier, taskIdentifier)
        XCTAssertEqual(submittedTask?.earliestBeginDate, self.now.addingTimeInterval(taskFrequency))
      }
    )
  }

  func testHandleUpdateTaskSchedulesAnotherUpdateTaskAndSavesSuccessResultToEnvironment() throws {
    let bear = App.bear
    let things = App.things
    let apps = [bear, things]

    var updatedThings = things
    updatedThings.version = "3.12.4"
    updatedThings.updateDate = now

    var lookupAppsSucceeds = true
    var appsToUpdate = [App.ID]()
    var updatedApps = [App]()

    let testStore = TestStore(
      initialState: BackgroundTaskState(
        updateAppsTask: BackgroundTaskConfiguration(id: "refresh-task", frequency: 10)
      ),
      reducer: backgroundTaskReducer,
      environment: systemEnvironment.map {
        BackgroundTaskEnvironment(
          submitTask: { _ in },
          fetchApps: { apps },
          lookupApps: { ids in
            appsToUpdate = ids
            return Future { subscriber in
              if lookupAppsSucceeds {
                subscriber(.success([updatedThings]))
              } else {
                subscriber(.failure(FetchAppsError()))
              }
            }.eraseToAnyPublisher()
          },
          saveUpdatedApps: { updatedApps = $0 }
        )
      }
    )

    let refreshTask = TestBackgroundTask(identifier: "refresh-task")

    testStore.assert(
      // Trigger success flow where apps are updated successfully
      .send(.handleAppUpdateTask(refreshTask)),
      .receive(.scheduleAppUpdateTask),
      .do { self.scheduler.advance(by: 1) },
      .do {
        XCTAssertNotNil(refreshTask.expirationHandler)
        XCTAssertEqual(refreshTask.taskCompletedResult, true)
        XCTAssertEqual(appsToUpdate, apps.map(\.id))
        XCTAssertEqual(updatedApps, [updatedThings])
      },

      // Reset test assertions
      .do {
        lookupAppsSucceeds = false
        refreshTask.taskCompletedResult = nil
        refreshTask.expirationHandler = nil
        appsToUpdate = []
        updatedApps = []
      },

      // Trigger error flow where apps fail to be updated
      .send(.handleAppUpdateTask(refreshTask)),
      .receive(.scheduleAppUpdateTask),
      .do { self.scheduler.advance(by: 1) },
      .do {
        XCTAssertNotNil(refreshTask.expirationHandler)
        XCTAssertEqual(refreshTask.taskCompletedResult, false)
        XCTAssertEqual(appsToUpdate, apps.map(\.id))
        XCTAssertEqual(updatedApps, [])
      }
    )
  }
}

private struct FetchAppsError: Error {}

private final class TestBackgroundTask: BackgroundTask {
  let identifier: String
  var taskCompletedResult: Bool?
  var expirationHandler: (() -> Void)?

  init(identifier: String) {
    self.identifier = identifier
  }

  func setTaskCompleted(success: Bool) {
    taskCompletedResult = success
  }
}

extension BackgroundTaskAction: Equatable {
  public static func == (_ lhs: BackgroundTaskAction, _ rhs: BackgroundTaskAction) -> Bool {
    switch (lhs, rhs) {
    case (.scheduleAppUpdateTask, .scheduleAppUpdateTask):
      return true
    case let (.handleAppUpdateTask(task1), .handleAppUpdateTask(task2)):
      return task1.identifier == task2.identifier
    case let (.failedToRegisterTask(task1), .failedToRegisterTask(task2)):
      return task1 == task2
    default:
      return false
    }
  }
}
