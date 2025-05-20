import Combine
import ComposableArchitecture
import Domain
import Foundation
import Toolbox
import XCTest

class AddAppsReducerTests: XCTestCase {
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

  func testAddAppsFromURLExtractsTheAppIDCorrectly() throws {
    var updatedApps: [AppDetails]?

    let testStore = TestStore(
      initialState: AddAppsState(
        apps: [],
        addingApps: false
      ),
      reducer: addAppsReducer,
      environment: systemEnvironment.map {
        AddAppsEnvironment(
          loadApps: { ids in
            Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
          },
          saveApps: { apps in
            updatedApps = apps
          }
        )
      }
    )

    let urls: [URL] = [
      URL(string: "https://apps.apple.com/au/id1016366447")!,
      URL(string: "https://itunes.apple.com/us/id1080840241")!,
      URL(string: "https://apps.apple.com/us/app/things-3/id904237743")!,
      URL(string: "https://apps.google.com/us/id5678")!,
    ]

    testStore.send(.addAppsFromURLs(urls))
    testStore.receive(.addApps([1_016_366_447, 1_080_840_241, 904_237_743])) {
      $0.addingApps = true
    }
    scheduler.advance()
    testStore.receive(.addAppsResponse(.success([]))) {
      $0.addingApps = false
    }
    XCTAssertNil(updatedApps)
  }
}
