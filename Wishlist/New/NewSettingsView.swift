import Combine
import Domain
import Foundation
import SwiftUI

final class SettingsViewModel: ObservableObject {
  struct Environment {
    var deleteAllApps: () throws -> Void
  }

  @Published var theme: Theme = .system

  private let environment: Environment

  init(environment: Environment) {
    self.environment = environment
  }

  func deleteAllApps() {
    do {
      try environment.deleteAllApps()
    } catch {
      print(error)
    }
  }
}

struct NewSettingsView: View {
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
    .navigationViewStyle(StackNavigationViewStyle())
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
