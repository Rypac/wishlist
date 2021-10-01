import Combine
import Domain
import Foundation
import Toolbox

enum SortOrder: String, CaseIterable, UserDefaultsSerializable {
  case title
  case price
  case updated
}

enum Theme: String, CaseIterable, UserDefaultsSerializable {
  case system
  case light
  case dark
}

extension ChangeNotification: UserDefaultsSerializable {}

final class Settings {
  @UserDefault("sortOrder", defaultValue: .updated)
  var sortOrder: SortOrder

  @UserDefault("lastUpdateCheck")
  var lastUpdateDate: Date?

  @UserDefault("theme", defaultValue: .system)
  var theme: Theme

  @UserDefault("enableNotifications", defaultValue: false)
  var enableNotificaitons: Bool

  @UserDefault("notifications", defaultValue: Set(ChangeNotification.allCases))
  var notifications: Set<ChangeNotification>

  func register() {
    _sortOrder.register()
    _lastUpdateDate.register()
    _theme.register()
    _enableNotificaitons.register()
    _notifications.register()
  }
}

extension Settings {
  var sortOrderStatePublisher: AnyPublisher<SortOrderState, Never> {
    $sortOrder.publisher()
      .map { sortOrder in
        SortOrderState(
          sortOrder: sortOrder,
          configuration: SortOrder.Configuration(
            price: SortOrder.Configuration.Price(sortLowToHigh: true, includeFree: true),
            title: SortOrder.Configuration.Title(sortAToZ: true),
            update: SortOrder.Configuration.Update(sortByMostRecent: true)
          )
        )
      }
      .eraseToAnyPublisher()
  }
}
