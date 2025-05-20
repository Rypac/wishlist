import Combine
import Domain
import Foundation
import SwiftUI
import UserDefaults

@MainActor
final class SettingsViewModel: ObservableObject {
  struct Environment {
    var theme: UserDefault<Theme>
    var notificationsEnabled: UserDefault<Bool>
    var deleteAllApps: () async throws -> Void
  }

  private let environment: Environment

  init(environment: Environment) {
    self.environment = environment
  }

  func deleteAllApps() {
    Task {
      do {
        try await environment.deleteAllApps()
      } catch {
        print(error)
      }
    }
  }

  var themeViewModel: UserDefaultViewModel<Theme> {
    UserDefaultViewModel(environment.theme)
  }

  var notificationsModel: NotificationsModel {
    NotificationsModel(notificationsEnabled: environment.notificationsEnabled)
  }
}

struct SettingsView: View {
  @StateObject var viewModel: SettingsViewModel

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section(header: Text("Appearance")) {
          SelectThemeView(viewModel: viewModel.themeViewModel)
        }
        Section(header: Text("Notifications")) {
          NotificationsView(model: viewModel.notificationsModel)
        }
        Section(header: Text("About")) {
          NavigationLink("Acknowledgements", destination: LicensesView.init)
          Link("Source Code", destination: URL(string: "https://github.com/Rypac/wishlist")!)
        }
        Section(
          header: Text("Danger Zone"),
          footer: Text("This will remove all apps from your Wishlist and cannot be undone.")
        ) {
          DeleteAllAppsView {
            viewModel.deleteAllApps()
          }
        }
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            dismiss()
          }
        }
      }
      .navigationTitle("Settings")
    }
  }
}

private struct SelectThemeView: View {
  @StateObject var viewModel: UserDefaultViewModel<Theme>

  var body: some View {
    Picker("Theme", selection: $viewModel.value) {
      ForEach(Theme.allCases, id: \.self) { theme in
        Text(theme.title).tag(theme)
      }
    }
    .pickerStyle(.segmented)
  }
}

private struct DeleteAllAppsView: View {
  let action: () -> Void

  @State private var showConfirmation = false

  var body: some View {
    Button("Delete All", role: .destructive) {
      showConfirmation = true
    }
    .alert("Are you sure you want to delete all apps?", isPresented: $showConfirmation) {
      Button("Delete", role: .destructive, action: action)
    } message: {
      Text("All apps will be deleted. This action cannot be undone.")
    }
  }
}

extension Theme {
  fileprivate var title: String {
    switch self {
    case .system: "System"
    case .light: "Light"
    case .dark: "Dark"
    }
  }
}
