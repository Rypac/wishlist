import UIKit

extension UIWindowScene {
  func setColorScheme(theme: Theme) {
    for window in windows {
      window.overrideUserInterfaceStyle = UIUserInterfaceStyle(theme)
      window.tintColor = UIColor(.blue)
    }
  }
}

private extension UIUserInterfaceStyle {
  init(_ theme: Theme) {
    switch theme {
    case .system: self = .unspecified
    case .light: self = .light
    case .dark: self = .dark
    }
  }
}
