import Foundation
import SwiftUI

struct SettingsView: View {
  @Environment(\.presentationMode) var presentationMode

  @EnvironmentObject var settings: SettingsStore

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Display")) {
          Picker("Sort order", selection: $settings.sortOrder) {
            ForEach(SortOrder.allCases, id: \.self) {
              Text($0.title).tag($0)
            }
          }
        }
      }
      .navigationBarTitle("Settings")
      .navigationBarItems(
        trailing: Button("Done") {
          self.presentationMode.wrappedValue.dismiss()
        }
      )
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
