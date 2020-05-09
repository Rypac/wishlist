import Foundation
import SwiftUI

extension DynamicViewContent where Data.Element: Identifiable, Data.Index == IndexSet.Element {
  @inlinable public func onDelete(perform action: (([Data.Element.ID]) -> Void)?) -> some DynamicViewContent {
    onDelete { [data] (indexes: IndexSet) in
      if let action = action {
        action(indexes.map { data[$0].id })
      }
    }
  }
}
