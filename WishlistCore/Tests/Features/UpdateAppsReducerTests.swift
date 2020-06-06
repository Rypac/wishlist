import BackgroundTasks
import Combine
import ComposableArchitecture
import Foundation
import WishlistCore
import WishlistFoundation
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
    let bear = App(.bear, firstAdded: now)
    let things = App(.things, firstAdded: now)

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

    let bear = App(.bear, firstAdded: now)
    let things = App(.things, firstAdded: now)

    var updatedThings = AppSnapshot.things
    updatedThings.version = "4.0.0"
    updatedThings.updateDate = now

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
        apps: [App(.bear, firstAdded: now)],
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
