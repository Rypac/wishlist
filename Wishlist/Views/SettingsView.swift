import Foundation
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var viewModel: SettingsViewModel

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Display")) {
          Picker(selection: $viewModel.sortOrder, label: Text("Sort order")) {
            ForEach(SortOrder.allCases, id: \.self) {
              Text($0.title).tag($0)
            }
          }
        }
      }
      .navigationBarTitle(Text("Settings"))
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
