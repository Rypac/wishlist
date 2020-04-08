import Combine
import SwiftUI
import UserDefaults
import WishlistData

extension SortOrder: UserDefaultsSerializable {}

final class SettingsStore {
  @UserDefault(key: "sortOrder", defaultValue: .price)
  var sortOrder: SortOrder

  func register() {
    _sortOrder.register()
  }
}

extension SettingsStore: ObservableObject {
  var objectWillChange: AnyPublisher<Void, Never> {
    NotificationCenter.default
      .publisher(for: UserDefaults.didChangeNotification)
      .map { _ in () }
      .eraseToAnyPublisher()
  }
}
