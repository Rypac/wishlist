import ComposableArchitecture
import Foundation

@dynamicMemberLookup
public struct SystemEnvironment<Environment> {
  public var environment: Environment
  public var now: () -> Date
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
      mainQueue: mainQueue
    )
  }
}

public extension SystemEnvironment {
  static func live(environment: Environment) -> Self {
    Self(
      environment: environment,
      now: Date.init,
      mainQueue: { DispatchQueue.main.eraseToAnyScheduler() }
    )
  }

#if DEBUG
  static func mock(
    environment: Environment,
    now: @escaping () -> Date,
    mainQueue: @escaping () -> AnySchedulerOf<DispatchQueue>
  ) -> Self {
    Self(
      environment: environment,
      now: now,
      mainQueue: { mainQueue().eraseToAnyScheduler() }
    )
  }
#endif
}
