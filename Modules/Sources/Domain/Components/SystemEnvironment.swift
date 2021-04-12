import CombineSchedulers
import Foundation

@dynamicMemberLookup
public struct SystemEnvironment<Environment> {
  public var environment: Environment
  public var now: () -> Date
  public var uuid: () -> UUID
  public var mainQueue: () -> AnySchedulerOf<DispatchQueue>

  public subscript<Dependency>(
    dynamicMember keyPath: WritableKeyPath<Environment, Dependency>
  ) -> Dependency {
    get { self.environment[keyPath: keyPath] }
    set { self.environment[keyPath: keyPath] = newValue }
  }

  public func map<NewEnvironment>(
    _ transform: (Environment) -> NewEnvironment
  ) -> SystemEnvironment<NewEnvironment> {
    SystemEnvironment<NewEnvironment>(
      environment: transform(environment),
      now: now,
      uuid: uuid,
      mainQueue: mainQueue
    )
  }
}

extension SystemEnvironment {
  public static func live(_ environment: Environment) -> Self {
    Self(
      environment: environment,
      now: Date.init,
      uuid: UUID.init,
      mainQueue: { DispatchQueue.main.eraseToAnyScheduler() }
    )
  }

#if DEBUG
  public static func mock(
    environment: Environment,
    now: @escaping () -> Date,
    uuid: @escaping () -> UUID,
    mainQueue: @escaping () -> AnySchedulerOf<DispatchQueue>
  ) -> Self {
    Self(
      environment: environment,
      now: now,
      uuid: uuid,
      mainQueue: mainQueue
    )
  }
#endif
}
