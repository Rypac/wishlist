import Combine
import Domain
import Foundation
import SwiftUI
import Toolbox
import ToolboxUI

struct ContentViewEnvironment {
  var repository: AllAppsRepository
  var theme: UserDefault<Theme>
  var sortOrderState: AnyPublisher<SortOrderState, Never>
  var checkForUpdates: () -> Void
  var system: SystemEnvironment<Void>
}

struct ContentView: View {
  let environment: ContentViewEnvironment

  @State private var showSettings = false

  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    NavigationView {
      AppListView(
        viewModel: AppListViewModel(
          environment: AppListViewModel.Environment(
            repository: environment.repository,
            sortOrder: environment.sortOrderState,
            system: environment.system
          )
        )
      )
        .navigationTitle("Wishlist")
        .navigationBarItems(
          trailing: Button(action: { showSettings = true }) {
            SFSymbol.settings
              .imageScale(.large)
              .accessibility(label: Text("Settings"))
              .frame(width: 24, height: 24)
          }
          .hoverEffect()
        )
    }
    .sheet(isPresented: $showSettings) {
      SettingsView(
        viewModel: SettingsViewModel(
          environment: SettingsViewModel.Environment(
            theme: environment.theme,
            deleteAllApps: environment.repository.deleteAllApps
          )
        )
      )
    }
    .onChange(of: scenePhase) { phase in
      if phase == .active {
        environment.checkForUpdates()
      }
    }
    .onReceive(environment.theme.publisher()) { theme in
      setColorScheme(theme: theme)
    }
  }
}

private func setColorScheme(theme: Theme) {
  let window = UIApplication.shared.windows.first
  window?.overrideUserInterfaceStyle = UIUserInterfaceStyle(theme)
  window?.tintColor = UIColor(.blue)
}
