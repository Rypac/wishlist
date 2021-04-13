import CombineSchedulers
import Foundation

public struct SystemEnvironment {
  public var now: () -> Date
  public var uuid: () -> UUID
  public var mainQueue: AnySchedulerOf<DispatchQueue>

  public init(
    now: @escaping () -> Date,
    uuid: @escaping () -> UUID,
    mainQueue: AnySchedulerOf<DispatchQueue>
  ) {
    self.now = now
    self.uuid = uuid
    self.mainQueue = mainQueue
  }
}

extension SystemEnvironment {
  public static var live: SystemEnvironment {
    SystemEnvironment(
      now: Date.init,
      uuid: UUID.init,
      mainQueue: .main
    )
  }
}
