import Foundation
import WishlistFoundation

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

final class Settings {
  @UserDefault(key: "sortOrder", defaultValue: .price)
  var sortOrder: SortOrder

  @UserDefault(key: "lastUpdateCheck", defaultValue: nil)
  var lastUpdateDate: Date?

  @UserDefault(key: "theme", defaultValue: .system)
  var theme: Theme

  @UserDefault(key: "enableNotifications", defaultValue: false)
  var enableNotificaitons: Bool

  func register() {
    _sortOrder.register()
    _lastUpdateDate.register()
    _theme.register()
    _enableNotificaitons.register()
  }
}
