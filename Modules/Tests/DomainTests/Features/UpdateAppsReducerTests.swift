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
    let bear = AppDetails(.bear, firstAdded: now)
    let things = AppDetails(.things, firstAdded: now)

    let testStore = TestStore(
      initialState: AppUpdateState(
        apps: [bear, things],
        lastUpdateDate: now,
        updateFrequency: 10,
        isUpdateInProgress: false
      ),
      reducer: appUpdateReducer,
      environment: systemEnvironment.map {
        AppUpdateEnvironment(
          lookupApps: { ids in
            Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
          }
        )
      }
    )

    testStore.assert(
      .send(.checkForUpdates)
    )
  }

  func testNoUpdateIsAttemptedWhenThereAreNoApps() throws {
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
          }
        )
      }
    )

    testStore.assert(
      .send(.checkForUpdates)
    )
  }

  func testUpdateIsAttemptedWhenOutsideLastUpdateThreshold() throws {
    let updateFrequency = TimeInterval(10)

    let bear = AppDetails(.bear, firstAdded: now)
    let things = AppDetails(.things, firstAdded: now)

    var updatedThings = AppSummary.things
    updatedThings.version = Version(name: "4.0.0", date: now, notes: nil)

    var expectedThingsUpdate = things
    expectedThingsUpdate.applyUpdate(updatedThings)

    let testStore = TestStore(
      initialState: AppUpdateState(
        apps: [bear, things],
        lastUpdateDate: now,
        updateFrequency: 10,
        isUpdateInProgress: false
      ),
      reducer: appUpdateReducer,
      environment: systemEnvironment.map {
        AppUpdateEnvironment(
          lookupApps: { ids in
            Just([updatedThings]).setFailureType(to: Error.self).eraseToAnyPublisher()
          }
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
        $0.apps = [bear, expectedThingsUpdate]
      }
    )
  }

  func testUpdateIsCancelledWhenRequested() throws {
    let testStore = TestStore(
      initialState: AppUpdateState(
        apps: [AppDetails(.bear, firstAdded: now)],
        lastUpdateDate: nil,
        updateFrequency: 10,
        isUpdateInProgress: false
      ),
      reducer: appUpdateReducer,
      environment: systemEnvironment.map {
        AppUpdateEnvironment(
          lookupApps: { ids in
            Empty(completeImmediately: false).eraseToAnyPublisher()
          }
        )
      }
    )

    testStore.assert(
      .send(.checkForUpdates) {
        $0.isUpdateInProgress = true
      },
      .send(.cancelUpdateCheck) {
        $0.isUpdateInProgress = false
      }
    )
  }
}
