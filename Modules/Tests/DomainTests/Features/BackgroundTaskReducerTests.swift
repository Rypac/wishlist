import BackgroundTasks
import Combine
import ComposableArchitecture
import Domain
import Foundation
import Toolbox
import XCTest

class BackgroundTaskReducerTests: XCTestCase {
  let scheduler = DispatchQueue.testScheduler
  let now = Date()
  let uuid = UUID()
  lazy var systemEnvironment: SystemEnvironment<Void> = {
    .test(
      now: { self.now },
      uuid: { self.uuid },
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

    testStore.send(.scheduleAppUpdateTask)
    scheduler.advance()
    XCTAssertEqual(submittedTask?.identifier, taskIdentifier)
    XCTAssertEqual(submittedTask?.earliestBeginDate, now.addingTimeInterval(taskFrequency))
  }

  func testHandleUpdateTaskSchedulesAnotherUpdateTaskAndSavesSuccessResultToEnvironment() throws {
    let bear = AppDetails(.bear, firstAdded: now)
    let things = AppDetails(.things, firstAdded: now)
    let apps = [bear, things]

    var updatedThings = AppSummary.things
    updatedThings.version = Version(name: "3.12.4", date: now, notes: nil)

    var appsToUpdate: [AppID]?
    var updatedApps: [AppDetails]?

    let testStore = TestStore(
      initialState: BackgroundTaskState(
        updateAppsTask: BackgroundTaskConfiguration(id: "refresh-task", frequency: 10)
      ),
      reducer: backgroundTaskReducer,
      environment: systemEnvironment.map {
        BackgroundTaskEnvironment(
          submitTask: { _ in },
          fetchApps: { [.bear, .things] },
          lookupApps: { ids in
            appsToUpdate = ids
            return Future { subscriber in
              subscriber(.success([updatedThings]))
            }
            .eraseToAnyPublisher()
          },
          saveUpdatedApps: { updatedApps = $0 }
        )
      }
    )

    let refreshTask = TestBackgroundTask(identifier: "refresh-task")

    // Success flow
    testStore.send(.handleAppUpdateTask(refreshTask))
    testStore.receive(.scheduleAppUpdateTask)
    scheduler.advance()
    XCTAssertNotNil(refreshTask.expirationHandler)
    XCTAssertEqual(refreshTask.taskCompletedResult, true)
    XCTAssertEqual(appsToUpdate, apps.map(\.id))
    XCTAssertEqual(updatedApps, [AppDetails(updatedThings, firstAdded: now)])

    // Reset test assertions
    refreshTask.reset()
    appsToUpdate = nil
    updatedApps = nil
    testStore.environment.lookupApps = { ids in
      appsToUpdate = ids
      return Future { subscriber in
        subscriber(.failure(FetchAppsError()))
      }
      .eraseToAnyPublisher()
    }

    // Failure to lookup apps flow
    testStore.send(.handleAppUpdateTask(refreshTask))
    testStore.receive(.scheduleAppUpdateTask)
    scheduler.advance()
    XCTAssertNotNil(refreshTask.expirationHandler)
    XCTAssertEqual(refreshTask.taskCompletedResult, false)
    XCTAssertEqual(appsToUpdate, apps.map(\.id))
    XCTAssertEqual(updatedApps, nil)
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

  func reset() {
    taskCompletedResult = nil
    expirationHandler = nil
  }
}

extension BackgroundTaskAction: Equatable {
  public static func == (_ lhs: BackgroundTaskAction, _ rhs: BackgroundTaskAction) -> Bool {
    switch (lhs, rhs) {
    case (.scheduleAppUpdateTask, .scheduleAppUpdateTask):
      true
    case let (.handleAppUpdateTask(task1), .handleAppUpdateTask(task2)):
      task1.identifier == task2.identifier
    case let (.failedToRegisterTask(task1), .failedToRegisterTask(task2)):
      task1 == task2
    default:
      false
    }
  }
}
