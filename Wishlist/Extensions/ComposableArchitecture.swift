import ComposableArchitecture
import SwiftUI

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
