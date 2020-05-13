import Foundation

enum SceneLifecycleEvent: Equatable {
  case willConnect
  case didDisconnect
  case didBecomeActive
  case willResignActive
  case willEnterForground
  case didEnterBackground
  case openURL(URL)
}
