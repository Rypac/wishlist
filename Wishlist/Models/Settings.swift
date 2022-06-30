import Combine
import Domain
import Foundation
import UserDefaults

enum SortOrder: String, CaseIterable, UserDefaultsConvertible {
  case title
  case price
  case updated
}

enum Theme: String, CaseIterable, UserDefaultsConvertible {
  case system
  case light
  case dark
}

extension ChangeNotification: UserDefaultsConvertible {}

final class Settings {
  @UserDefault("sortOrder", defaultValue: .updated)
  var sortOrder: SortOrder

  @OptionalUserDefault("lastUpdateCheck")
  var lastUpdateDate: Date?

  @UserDefault("theme", defaultValue: .system)
  var theme: Theme

  @UserDefault("enableNotifications", defaultValue: false)
  var enableNotificaitons: Bool

  @UserDefault("notifications", defaultValue: Set(ChangeNotification.allCases))
  var notifications: Set<ChangeNotification>

  func register() {
    _sortOrder.register()
    _theme.register()
    _enableNotificaitons.register()
    _notifications.register()
  }
}

extension Settings {
  var sortOrderStatePublisher: some Publisher<SortOrderState, Never> {
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
  }
}
