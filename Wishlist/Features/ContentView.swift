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
  var refresh: () async -> Void
  var checkForUpdates: () async throws -> Void
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
        Task {
          await environment.refresh()
          try? await environment.checkForUpdates()
        }
      case .background:
        try? environment.scheduleBackgroundTasks()
      default:
        break
      }
    }
    .theme(environment.theme)
    .navigationViewStyle(.stack)
  }
}
