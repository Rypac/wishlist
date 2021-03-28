import UIKit
import Domain

protocol SceneDescriptor {
  var id: String { get }
  var configuration: UISceneConfiguration { get }
}

struct SceneDescription<Delegate: UIWindowSceneDelegate>: Identifiable, SceneDescriptor {
  let name: String
  let delegate: Delegate.Type

  init(name: String, delegate: Delegate.Type) {
    self.name = name
    self.delegate = delegate
  }

  var id: String { "org.rypac.wishlist.\(name)" }

  var configuration: UISceneConfiguration {
    let configuration = UISceneConfiguration(name: name, sessionRole: .windowApplication)
    configuration.delegateClass = delegate
    configuration.sceneClass = UIWindowScene.self
    return configuration
  }
}

struct DefaultScene {
//  static let description = SceneDescription(name: "Default", delegate: SceneDelegate.self)
}

struct DetailsScene {
//  static let description = SceneDescription(name: "Details", delegate: AppDetailsDelegate.self)

  let id: AppID
}

extension DetailsScene {
  private static let idKey = "appID"

  init?(userInfo: [AnyHashable: Any]) {
    guard let id = userInfo[DetailsScene.idKey] as? Int else {
      return nil
    }
    self.id = AppID(rawValue: id)
  }

//  var userActivity: NSUserActivity {
//    let userActivity = NSUserActivity(activityType: Self.description.id)
//    userActivity.addUserInfoEntries(from: [DetailsScene.idKey: id.rawValue])
//    return userActivity
//  }
}

//func sceneConfiguration(for activity: NSUserActivity) -> UISceneConfiguration? {
//  let scenes: [SceneDescriptor] = [DefaultScene.description, DetailsScene.description]
//  return scenes.first(where: { $0.id == activity.activityType })?.configuration
//}
