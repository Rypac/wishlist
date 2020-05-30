import ComposableArchitecture
import Foundation
import WishlistCore

extension SystemEnvironment where Environment == Void {
  static func test(
    now: @escaping () -> Date,
    uuid: @escaping () -> UUID,
    mainQueue: @escaping () -> AnySchedulerOf<DispatchQueue>
  ) -> Self {
    .mock(
      environment: (),
      now: now,
      uuid: uuid,
      mainQueue: mainQueue
    )
  }
}
