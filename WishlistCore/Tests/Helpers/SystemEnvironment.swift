import ComposableArchitecture
import Foundation
import WishlistCore

extension SystemEnvironment where Environment == Void {
  static func test(
    now: @escaping () -> Date,
    mainQueue: @escaping () -> AnySchedulerOf<DispatchQueue>
  ) -> Self {
    .mock(
      environment: (),
      now: now,
      mainQueue: { mainQueue().eraseToAnyScheduler() }
    )
  }
}
