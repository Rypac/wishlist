import ComposableArchitecture
import SwiftUI

extension Reducer {
  public static func strict(
    _ reducer: @escaping (inout State, Action) -> (Environment) -> Effect<Action, Never>
  ) -> Reducer {
    Reducer { state, action, environment in
      reducer(&state, action)(environment)
    }
  }
}

extension Store {
  public var stateless: Store<Void, Action> {
    scope(state: { _ in () })
  }

  public var actionless: Store<State, Never> {
    func absurd<A>(_ never: Never) -> A {}
    return scope(state: { $0 }, action: absurd)
  }
}

extension WithViewStore where State == Void {
  public init(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.init(store, removeDuplicates: ==, content: content)
  }
}
