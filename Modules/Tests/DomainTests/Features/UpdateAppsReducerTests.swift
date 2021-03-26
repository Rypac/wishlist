import BackgroundTasks
import Combine
import ComposableArchitecture
import Foundation
import Domain
import Toolbox
import XCTest

class UpdateAppsReducerTests: XCTestCase {
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

  func testNoUpdateIsAttemptedWhenWithinLastUpdateThreshold() throws {
    var updatedApps: [AppSummary]?

    let testStore = TestStore(
      initialState: AppUpdateState(
        apps: [details(.bear), details(.things)],
        lastUpdateDate: now,
        updateFrequency: 10,
        isUpdateInProgress: false
      ),
      reducer: appUpdateReducer,
      environment: systemEnvironment.map {
        AppUpdateEnvironment(
          lookupApps: { ids in
            Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
          },
          saveApps: { updatedApps = $0 }
        )
      }
    )

    testStore.send(.checkForUpdates)
    XCTAssertNil(updatedApps)
  }

  func testNoUpdateIsAttemptedWhenThereAreNoApps() throws {
    var updatedApps: [AppSummary]?

    let testStore = TestStore(
      initialState: AppUpdateState(
        apps: [],
        lastUpdateDate: nil,
        updateFrequency: 10,
        isUpdateInProgress: false
      ),
      reducer: appUpdateReducer,
      environment: systemEnvironment.map {
        AppUpdateEnvironment(
          lookupApps: { ids in
            Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
          },
          saveApps: { updatedApps = $0 }
        )
      }
    )

    testStore.send(.checkForUpdates)
    XCTAssertNil(updatedApps)
  }

  func testUpdateIsAttemptedWhenOutsideLastUpdateThreshold() throws {
    let updateFrequency = TimeInterval(10)

    var updatedThings = AppSummary.things
    updatedThings.version = Version(name: "4.0.0", date: now, notes: nil)

    var updatedApps: [AppSummary]?

    let testStore = TestStore(
      initialState: AppUpdateState(
        apps: [details(.bear), details(.things)],
        lastUpdateDate: now,
        updateFrequency: 10,
        isUpdateInProgress: false
      ),
      reducer: appUpdateReducer,
      environment: systemEnvironment.map {
        AppUpdateEnvironment(
          lookupApps: { ids in
            Just([updatedThings]).setFailureType(to: Error.self).eraseToAnyPublisher()
          },
          saveApps: { updatedApps = $0 }
        )
      }
    )

    let someFutureDate = now.addingTimeInterval(updateFrequency)

    testStore.send(.checkForUpdates)
    testStore.environment.now = { someFutureDate }
    testStore.send(.checkForUpdates) {
      $0.isUpdateInProgress = true
    }
    scheduler.advance()
    testStore.receive(.receivedUpdates(.success([updatedThings]), at: someFutureDate)) {
      $0.isUpdateInProgress = false
      $0.lastUpdateDate = someFutureDate
    }
    XCTAssertEqual(updatedApps, [updatedThings])
  }

  func testUpdateIsCancelledWhenRequested() throws {
    var updatedApps: [AppSummary]?

    let testStore = TestStore(
      initialState: AppUpdateState(
        apps: [details(.bear)],
        lastUpdateDate: nil,
        updateFrequency: 10,
        isUpdateInProgress: false
      ),
      reducer: appUpdateReducer,
      environment: systemEnvironment.map {
        AppUpdateEnvironment(
          lookupApps: { ids in
            Empty(completeImmediately: false).eraseToAnyPublisher()
          },
          saveApps: { updatedApps = $0 }
        )
      }
    )

    testStore.send(.checkForUpdates) {
      $0.isUpdateInProgress = true
    }
    testStore.send(.cancelUpdateCheck) {
      $0.isUpdateInProgress = false
    }
    XCTAssertNil(updatedApps)
  }
}

private extension UpdateAppsReducerTests {
  func details(_ summary: AppSummary) -> AppDetails {
    AppDetails(summary, firstAdded: now.addingTimeInterval(-20000))
  }
}
