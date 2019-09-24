import Combine
import SwiftUI

protocol Settings: class {
  var sortOrder: SortOrder { get set }
}

protocol ObservableSettings: Settings {
  var sortOrderPublisher: AnyPublisher<SortOrder, Never> { get }
  var didChange: AnyPublisher<Void, Never> { get }
}

final class SettingsStore: Settings {
  @UserDefault(key: "sortOrder", defaultValue: .price)
  var sortOrder: SortOrder
}

extension SettingsStore: ObservableSettings {
  var sortOrderPublisher: AnyPublisher<SortOrder, Never> {
    _sortOrder.publisher.eraseToAnyPublisher()
  }

  var didChange: AnyPublisher<Void, Never> {
    NotificationCenter.default
      .publisher(for: UserDefaults.didChangeNotification)
      .map { _ in () }
      .eraseToAnyPublisher()
  }
}
