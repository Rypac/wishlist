import Domain
import Foundation
import SwiftUI

struct NewSettingsView: View {
  @State var theme = Theme.system

  @Environment(\.presentationMode) private var presentationMode
  @Environment(\.openURL) private var openURL

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Appearance")) {
          Picker("Theme", selection: $theme) {
            ForEach(Theme.allCases, id: \.self) { theme in
              Text(theme.title).tag(theme)
            }
          }
          .pickerStyle(SegmentedPickerStyle())
        }
        Section(header: Text("Notifications")) {
          NotificationsView()
        }
        Section(header: Text("About")) {
          NavigationLink("Acknowledgements", destination: LicensesView())
          Button("Source Code") {
            openURL(URL(string: "https://github.com/Rypac/wishlist")!)
          }
        }
        Section(
          header: Text("Danger Zone"),
          footer: Text("This will remove all apps from your Wishlist and cannot be undone.")
        ) {
          Button("Delete All") {
            // TODO: Delete all the apps
          }
          .foregroundColor(.red)
        }
      }
      .navigationBarTitle("Settings")
      .navigationBarItems(trailing: Button("Close") {
        presentationMode.wrappedValue.dismiss()
      })
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }
}

private extension Theme {
  var title: String {
    switch self {
    case .system: return "System"
    case .light: return "Light"
    case .dark: return "Dark"
    }
  }
}
