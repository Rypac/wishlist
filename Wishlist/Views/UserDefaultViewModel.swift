import SwiftUI
import Toolbox

@MainActor
public final class UserDefaultViewModel<Value>: ObservableObject {
  private var userDefault: UserDefault<Value>

  @Published public var value: Value {
    willSet {
      userDefault.wrappedValue = newValue
    }
  }

  public init(_ userDefault: UserDefault<Value>) {
    self.userDefault = userDefault
    self.value = userDefault.wrappedValue
    self.userDefault.publisher().assign(to: &$value)
  }
}
