import Foundation
import Domain
import DomainUI
import Toolbox

extension Theme: UserDefaultsConvertible {}

extension SortOrder: UserDefaultsConvertible {}

extension ChangeNotification: UserDefaultsConvertible {}

final class Settings {
  @UserDefault("sortOrder", defaultValue: .price)
  var sortOrder: SortOrder

  @UserDefault("lastUpdateCheck", defaultValue: nil)
  var lastUpdateDate: Date?

  @UserDefault("theme", defaultValue: .system)
  var theme: Theme

  @UserDefault("enableNotifications", defaultValue: false)
  var enableNotificaitons: Bool

  @UserDefault(UserDefaultsKey("notifications", defaultValue: Set(ChangeNotification.allCases)))
  var notifications: Set<ChangeNotification>

  func register() {
    _sortOrder.register()
    _lastUpdateDate.register()
    _theme.register()
    _enableNotificaitons.register()
    _notifications.register()
  }
}
