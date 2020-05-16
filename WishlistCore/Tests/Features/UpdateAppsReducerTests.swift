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
  lazy var systemEnvironment: SystemEnvironment<Void> = {
    .test(
      now: { self.now },
      mainQueue: { self.scheduler.eraseToAnyScheduler() }
    )
  }()

  func testNoUpdateIsAttemptedWhenWithinLastUpdateThreshold() throws {
    let testStore = TestStore(
      initialState: AppUpdateState(
        apps: [.bear, .things],
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

    var updatedThings = App.things
    updatedThings.updateDate = now

    let testStore = TestStore(
      initialState: AppUpdateState(
        apps: [App.bear, .things],
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
        $0.apps = [.bear, updatedThings]
      }
    )
  }
}
