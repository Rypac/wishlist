import Combine
import Domain
import Foundation
import SwiftUI
import ToolboxUI

struct ContentViewEnvironment {
  var apps: AnyPublisher<[AppDetails], Never>
  var deleteApps: ([AppID]) throws -> Void
  var deleteAllApps: () throws -> Void
  var versionHistory: (AppDetails.ID) -> AnyPublisher<[Version], Never>
  var sortOrderState: AnyPublisher<SortOrderState, Never>
  var checkForUpdates: () -> Void
}

struct ContentView: View {
  let environment: ContentViewEnvironment

  @State private var showSettings = false

  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    NavigationView {
      NewAppListView(
        viewModel: AppListViewModel(
          environment: AppListViewModel.Environment(
            apps: environment.apps,
            sortOrder: environment.sortOrderState,
            deleteApps: environment.deleteApps,
            versionHistory: environment.versionHistory
          )
        )
      )
        .navigationTitle("Wishlist")
        .navigationBarItems(
          trailing: Button(action: { showSettings = true }) {
            SFSymbol.sliderHorizontal3
              .imageScale(.large)
              .accessibility(label: Text("Settings"))
              .frame(width: 24, height: 24)
          }
          .hoverEffect()
        )
    }
    .sheet(isPresented: $showSettings) {
      NewSettingsView(
        viewModel: SettingsViewModel(
          environment: SettingsViewModel.Environment(deleteAllApps: environment.deleteAllApps)
        )
      )
    }
    .onChange(of: scenePhase) { phase in
      if phase == .active {
        environment.checkForUpdates()
      }
    }
  }
}
