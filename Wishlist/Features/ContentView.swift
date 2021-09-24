import Combine
import Domain
import Foundation
import SwiftUI
import Toolbox
import ToolboxUI

struct ContentViewEnvironment {
  var repository: AppListRepository
  var theme: UserDefault<Theme>
  var sortOrderState: AnyPublisher<SortOrderState, Never>
  var refresh: () -> Void
  var checkForUpdates: () -> Void
  var scheduleBackgroundTasks: () throws -> Void
  var system: SystemEnvironment
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
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Button {
              showSettings = true
            } label: {
              SFSymbol.settings
                .accessibilityLabel("Settings")
            }
          }
        }
        .navigationTitle("Wishlist")
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
      switch phase {
      case .active:
        environment.refresh()
        environment.checkForUpdates()
      case .background:
        try? environment.scheduleBackgroundTasks()
      default:
        break
      }
    }
    .onReceive(environment.theme.publisher()) { theme in
      for scene in UIApplication.shared.connectedScenes {
        if let windowScene = scene as? UIWindowScene {
          windowScene.setColorScheme(theme: theme)
        }
      }
    }
    .navigationViewStyle(.stack)
  }
}
