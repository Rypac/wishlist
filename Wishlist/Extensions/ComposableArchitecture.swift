import ComposableArchitecture
import SwiftUI

extension WithViewStore where State == Void {
  public init(
    _ store: Store<State, Action>,
    @ViewBuilder content: @escaping (ViewStore<State, Action>) -> Content
  ) {
    self.init(store, removeDuplicates: ==, content: content)
  }
}
