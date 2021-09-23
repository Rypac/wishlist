import Combine
import Domain
import Foundation
import SwiftUI
import Toolbox

final class SettingsViewModel: ObservableObject {
  struct Environment {
    var theme: UserDefault<Theme>
    var deleteAllApps: () throws -> Void
  }

  @Published var theme: Theme {
    willSet {
      environment.theme.wrappedValue = newValue
    }
  }

  private var environment: Environment

  init(environment: Environment) {
    self.environment = environment
    theme = environment.theme.wrappedValue
    environment.theme.publisher().assign(to: &$theme)
  }

  func deleteAllApps() {
    do {
      try environment.deleteAllApps()
    } catch {
      print(error)
    }
  }
}

struct SettingsView: View {
  @StateObject var viewModel: SettingsViewModel

  @Environment(\.presentationMode) private var presentationMode
  @Environment(\.openURL) private var openURL

  @State private var showDeleteAllConfirmation = false

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Appearance")) {
          Picker("Theme", selection: $viewModel.theme) {
            ForEach(Theme.allCases, id: \.self) { theme in
              Text(theme.title).tag(theme)
            }
          }
          .pickerStyle(.segmented)
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
            showDeleteAllConfirmation = true
          }
          .foregroundColor(.red)
        }
      }
      .navigationBarTitle("Settings")
      .navigationBarItems(trailing: Button("Close") {
        presentationMode.wrappedValue.dismiss()
      })
    }
    .navigationViewStyle(.stack)
    .alert(isPresented: $showDeleteAllConfirmation) {
      Alert(
        title: Text("Are you sure you want to delete all apps?"),
        message: Text("All apps will be deleted. This action cannot be undone."),
        primaryButton: .destructive(Text("Delete")) {
          viewModel.deleteAllApps()
        },
        secondaryButton: .cancel()
      )
    }
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
