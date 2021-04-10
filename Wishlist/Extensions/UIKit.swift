import UIKit

extension UIApplication {
  func setColorScheme(theme: Theme) {
    if let window = windows.first {
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
