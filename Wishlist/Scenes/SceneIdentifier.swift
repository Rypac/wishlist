import UIKit

enum SceneIdentifier: String {
  enum UserInfoKey: String {
    case id
  }

  case `default` = "org.rypac.wishlist.default"
  case details = "org.rypac.wishlist.details"

  var configuration: UISceneConfiguration {
    switch self {
    case .default:
      let configuration = UISceneConfiguration(name: "Default", sessionRole: .windowApplication)
      configuration.delegateClass = SceneDelegate.self
      configuration.sceneClass = UIWindowScene.self
      return configuration
    case .details:
      let configuration = UISceneConfiguration(name: "Details", sessionRole: .windowApplication)
      configuration.delegateClass = AppDetailsDelegate.self
      configuration.sceneClass = UIWindowScene.self
      return configuration
    }
  }
}

extension SceneIdentifier {
  init?(activity: NSUserActivity) {
    self.init(rawValue: activity.activityType)
  }
}

extension NSUserActivity {
  convenience init(scene identifier: SceneIdentifier) {
    self.init(activityType: identifier.rawValue)
  }
}
