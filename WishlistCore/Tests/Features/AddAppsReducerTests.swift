import Combine
import ComposableArchitecture
import Foundation
import WishlistCore
import WishlistFoundation
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
    let testStore = TestStore(
      initialState: AddAppsState(apps: []),
      reducer: addAppsReducer,
      environment: systemEnvironment.map {
        AddAppsEnvironment(
          loadApps: { ids in
            Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
          }
        )
      }
    )

    let urls: [URL] = [
      URL(string: "https://apps.apple.com/au/id1016366447")!,
      URL(string: "https://itunes.apple.com/us/id1080840241")!,
      URL(string: "https://apps.apple.com/us/app/things-3/id904237743")!,
      URL(string: "https://apps.google.com/us/id5678")!
    ]

    testStore.assert(
      .send(.addAppsFromURLs(urls)),
      .receive(.addApps([1016366447, 1080840241, 904237743])),
      .do { self.scheduler.advance(by: 1) },
      .receive(.addAppsResponse(.success([])))
    )
  }

}
