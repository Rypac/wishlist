import ComposableArchitecture
import SwiftUI

struct SettingsState: Equatable {
  var theme: Theme
}

enum SettingsAction {
  case setTheme(Theme)
  case viewSourceCode
}

struct SettingsEnvironment {
  var saveTheme: (Theme) -> Void
  var openURL: (URL) -> Void
}

let settingsReducer = Reducer<SettingsState, SettingsAction, SettingsEnvironment> { state, action, environment in
  switch action {
  case let .setTheme(theme):
    state.theme = theme
    return .fireAndForget {
      environment.saveTheme(theme)
    }

  case .viewSourceCode:
    return .fireAndForget {
      environment.openURL(URL(string: "https://github.com/Rypac/wishlist")!)
    }
  }
}

struct SettingsView: View {
  let store: Store<SettingsState, SettingsAction>

  @Environment(\.presentationMode) var presentationMode

  var body: some View {
    WithViewStore(store) { viewStore in
      NavigationView {
        Form {
          Section(header: Text("Appearance")) {
            Picker("Theme", selection: viewStore.binding(get: \.theme, send: SettingsAction.setTheme)) {
              ForEach(Theme.allCases, id: \.self) { theme in
                Text(theme.title).tag(theme)
              }
            }.pickerStyle(SegmentedPickerStyle())
          }
          Section(header: Text("About")) {
            Button("Source Code") {
              viewStore.send(.viewSourceCode)
            }
          }
        }
        .navigationBarTitle("Settings")
        .navigationBarItems(trailing: Button("Close") {
          self.presentationMode.wrappedValue.dismiss()
        })
      }.navigationViewStyle(StackNavigationViewStyle())
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
