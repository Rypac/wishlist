import UIKit
import DomainUI

extension UIUserInterfaceStyle {
  init(_ theme: Theme) {
    switch theme {
    case .system: self = .unspecified
    case .light: self = .light
    case .dark: self = .dark
    }
  }
}
