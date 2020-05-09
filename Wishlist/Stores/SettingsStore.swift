import Foundation
import UserDefaults
import WishlistData

extension SortOrder: UserDefaultsSerializable {}

final class SettingsStore {
  @UserDefault(key: "sortOrder", defaultValue: .price)
  var sortOrder: SortOrder

  @UserDefault(key: "lastUpdateCheck", defaultValue: nil)
  var lastUpdateDate: Date?

  func register() {
    _sortOrder.register()
    _lastUpdateDate.register()
  }
}
