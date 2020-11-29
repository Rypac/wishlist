import Foundation
import Combine
import SwiftUI

public class SettingsViewModel: ViewModel {
  public struct State {
    var theme: Theme
    let sourceCodeURL: URL
  }

  public enum Action {
    case deleteApps
    case setTheme(Theme)
  }

  @Published public var state: State = State(
    theme: .system,
    sourceCodeURL: URL(string: "https://github.com/Rypac/wishlist")!
  )

  private let deleteApps: () -> Void

  public init(deleteApps: @escaping () -> Void) {
    self.deleteApps = deleteApps
  }

  public func send(_ action: Action) {
    switch action {
    case .deleteApps:
      deleteApps()
    case .setTheme(let theme):
      state.theme = theme
    }
  }
}

public struct SettingsView: View {
  @ObservedObject private var viewModel: SettingsViewModel

  @Environment(\.openURL) private var openURL
  @Environment(\.presentationMode) private var presentationMode

  public init(viewModel: SettingsViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Appearance")) {
          ThemePicker(selectedTheme: viewModel.binding(get: \.theme, send: SettingsViewModel.Action.setTheme))
        }
        Section(header: Text("Notifications")) {
          Text("Notification View")
        }
        Section(header: Text("About")) {
          NavigationLink("Acknowledgements", destination: LicensesView())
          Button("Source Code") {
            openURL(viewModel.sourceCodeURL)
          }
        }
        Section(
          header: Text("Danger Zone"),
          footer: Text("This will remove all apps from your Wishlist and cannot be undone.")
        ) {
          Button("Delete All") {
            viewModel(.deleteApps)
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

private struct ThemePicker: View {
  @Binding var selectedTheme: Theme

  var body: some View {
    Picker("Theme", selection: $selectedTheme) {
      ForEach(Theme.allCases, id: \.self) { theme in
        Text(theme.title).tag(theme)
      }
    }
    .pickerStyle(SegmentedPickerStyle())
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
