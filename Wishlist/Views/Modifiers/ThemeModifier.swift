import SwiftUI
import UserDefaults

extension View {
  func theme(_ theme: UserDefault<Theme>) -> some View {
    onReceive(theme.publisher().removeDuplicates()) { theme in
      for scene in UIApplication.shared.connectedScenes {
        if let windowScene = scene as? UIWindowScene {
          for window in windowScene.windows {
            window.overrideUserInterfaceStyle = UIUserInterfaceStyle(theme)
            window.tintColor = UIColor(.blue)
          }
        }
      }
    }
  }
}

extension UIUserInterfaceStyle {
  fileprivate init(_ theme: Theme) {
    switch theme {
    case .system: self = .unspecified
    case .light: self = .light
    case .dark: self = .dark
    }
  }
}

extension ColorScheme {
  fileprivate init?(_ theme: Theme) {
    switch theme {
    case .system: return nil
    case .light: self = .light
    case .dark: self = .dark
    }
  }
}
