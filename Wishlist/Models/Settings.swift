import Foundation
import UserDefaults

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

final class Settings {
  @UserDefault(key: "sortOrder", defaultValue: .price)
  var sortOrder: SortOrder

  @UserDefault(key: "lastUpdateCheck", defaultValue: nil)
  var lastUpdateDate: Date?

  @UserDefault(key: "theme", defaultValue: .system)
  var theme: Theme

  func register() {
    _sortOrder.register()
    _lastUpdateDate.register()
    _theme.register()
  }
}
