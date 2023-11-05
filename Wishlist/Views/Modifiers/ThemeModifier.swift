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

private extension UIUserInterfaceStyle {
  init(_ theme: Theme) {
    self = switch theme {
    case .system: .unspecified
    case .light: .light
    case .dark: .dark
    }
  }
}

private extension ColorScheme {
  init?(_ theme: Theme) {
    switch theme {
    case .system: return nil
    case .light: self = .light
    case .dark: self = .dark
    }
  }
}
