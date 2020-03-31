import UserDefaults

enum SortOrder: String, CaseIterable, UserDefaultsSerializable {
  case title
  case price
  case updated
}
