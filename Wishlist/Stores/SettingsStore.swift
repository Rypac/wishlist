import Combine
import SwiftUI
import UserDefaults
import WishlistShared

extension SortOrder: UserDefaultsSerializable {}

final class SettingsStore {
  @UserDefault(key: "sortOrder", defaultValue: .price)
  var sortOrder: SortOrder

  @UserDefault(key: "lastUpdateCheck", defaultValue: nil)
  var lastUpdateCheck: Date?

  func register() {
    _sortOrder.register()
    _lastUpdateCheck.register()
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
