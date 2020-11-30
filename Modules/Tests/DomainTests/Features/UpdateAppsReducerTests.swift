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
          fetchApps: {
            [.bear, .things]
          },
          saveApps: { updatedApps = $0 }
        )
      }
    )

    testStore.assert(
      .send(.checkForUpdates),
      .do {
        XCTAssertNil(updatedApps)
      }
    )
  }

  func testNoUpdateIsAttemptedWhenThereAreNoApps() throws {
    var updatedApps: [AppSummary]?

    let testStore = TestStore(
      initialState: AppUpdateState(
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
          fetchApps: { [] },
          saveApps: { updatedApps = $0 }
        )
      }
    )

    testStore.assert(
      .send(.checkForUpdates),
      .do {
        XCTAssertNil(updatedApps)
      }
    )
  }

  func testUpdateIsAttemptedWhenOutsideLastUpdateThreshold() throws {
    let updateFrequency = TimeInterval(10)

    var updatedThings = AppSummary.things
    updatedThings.version = Version(name: "4.0.0", date: now, notes: nil)

    var updatedApps: [AppSummary]?

    let testStore = TestStore(
      initialState: AppUpdateState(
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
          fetchApps: {
            [.bear, .things]
          },
          saveApps: { updatedApps = $0 }
        )
      }
    )

    let someFutureDate = now.addingTimeInterval(updateFrequency)

    testStore.assert(
      .send(.checkForUpdates),

      .environment {
        $0.now = { someFutureDate }
      },

      .send(.checkForUpdates) {
        $0.isUpdateInProgress = true
      },
      .do { self.scheduler.advance(by: 1) },
      .receive(.receivedUpdates(.success([updatedThings]), at: someFutureDate)) {
        $0.isUpdateInProgress = false
        $0.lastUpdateDate = someFutureDate
      },
      .do {
        XCTAssertEqual(updatedApps, [updatedThings])
      }
    )
  }

  func testUpdateIsCancelledWhenRequested() throws {
    var updatedApps: [AppSummary]?

    let testStore = TestStore(
      initialState: AppUpdateState(
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
          fetchApps: { [.bear] },
          saveApps: { updatedApps = $0 }
        )
      }
    )

    testStore.assert(
      .send(.checkForUpdates) {
        $0.isUpdateInProgress = true
      },
      .send(.cancelUpdateCheck) {
        $0.isUpdateInProgress = false
      },
      .do {
        XCTAssertNil(updatedApps)
      }
    )
  }
}
