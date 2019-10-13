import Foundation
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var viewModel: SettingsViewModel

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Display")) {
          Picker("Sort order", selection: $viewModel.sortOrder) {
            ForEach(SortOrder.allCases, id: \.self) {
              Text($0.title).tag($0)
            }
          }
        }
      }
      .navigationBarTitle("Settings")
    }
  }
}

private extension SortOrder {
  var title: String {
    switch self {
    case .price: return "Price"
    case .title: return "Title"
    }
  }
}
