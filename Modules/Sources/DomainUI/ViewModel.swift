import SwiftUI

@dynamicMemberLookup
public protocol ViewModel: ObservableObject {
  associatedtype State
  associatedtype Action

  var state: State { get set }

  func send(_ action: Action)
}

extension ViewModel {
  public subscript<T>(dynamicMember keyPath: KeyPath<State, T>) -> T {
    self.state[keyPath: keyPath]
  }

  public subscript<T>(dynamicMember keyPath: WritableKeyPath<State, T>) -> T {
    get { self.state[keyPath: keyPath] }
    set { self.state[keyPath: keyPath] = newValue }
  }
}

extension ViewModel {
  public func callAsFunction(_ action: Action) {
    send(action)
  }
}

extension ViewModel {
  public func binding<T>(
    get: @escaping (State) -> T,
    send localStateToViewAction: @escaping (T) -> Action
  ) -> Binding<T> {
    Binding(
      get: { get(self.state) },
      set: { newLocalState, transaction in
        withAnimation(transaction.disablesAnimations ? nil : transaction.animation) {
          self.send(localStateToViewAction(newLocalState))
        }
      }
    )
  }

  public func binding<T>(
    get: @escaping (State) -> T,
    send action: Action
  ) -> Binding<T> {
    binding(get: get, send: { _ in action })
  }
}
