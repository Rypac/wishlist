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
