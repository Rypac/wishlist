import UIKit

enum ActivityIdentifier: String {
  enum UserInfoKey: String {
    case id
  }

  case list = "org.rypac.wishlist.list"
  case details = "org.rypac.wishlist.details"

  var sceneConfiguration: UISceneConfiguration {
    switch self {
    case .details:
      return UISceneConfiguration(name: SceneConfigurationNames.details, sessionRole: .windowApplication)
    case .list:
      return UISceneConfiguration(name: SceneConfigurationNames.standard, sessionRole: .windowApplication)
    }
  }
}
