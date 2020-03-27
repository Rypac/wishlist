import Foundation
import SwiftUI

struct UpdateDateFormatterKey: EnvironmentKey {
  static let defaultValue: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    formatter.doesRelativeDateFormatting = true
    return formatter
  }()
}

extension EnvironmentValues {
  var updateDateFormatter: DateFormatter {
    self[UpdateDateFormatterKey.self]
  }
}
