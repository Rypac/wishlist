import Foundation

public struct SystemEnvironment {
  public var now: () -> Date
  public var uuid: () -> UUID

  public init(
    now: @escaping () -> Date,
    uuid: @escaping () -> UUID
  ) {
    self.now = now
    self.uuid = uuid
  }
}

extension SystemEnvironment {
  public static var live: SystemEnvironment {
    SystemEnvironment(
      now: Date.init,
      uuid: UUID.init
    )
  }
}
