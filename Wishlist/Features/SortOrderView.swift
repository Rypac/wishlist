import SwiftUI
import Toolbox

extension SortOrder {
  struct Configuration: Equatable {
    struct Price: Equatable {
      var sortLowToHigh: Bool
      var includeFree: Bool
    }

    struct Title: Equatable {
      var sortAToZ: Bool
    }

    struct Update: Equatable {
      var sortByMostRecent: Bool
    }

    var price: Price
    var title: Title
    var update: Update
  }
}

struct SortOrderState: Equatable {
  var sortOrder: SortOrder
  var configuration: SortOrder.Configuration
}
