import Combine
import SwiftUI
import UserDefaults

final class SettingsStore {
  @UserDefault(key: "sortOrder", defaultValue: .price)
  var sortOrder: SortOrder
}

extension SettingsStore: ObservableObject {
  var objectWillChange: AnyPublisher<Void, Never> {
    NotificationCenter.default
      .publisher(for: UserDefaults.didChangeNotification)
      .map { _ in () }
      .eraseToAnyPublisher()
  }
}
