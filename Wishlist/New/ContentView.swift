import Combine
import Domain
import SwiftUI
import ToolboxUI

struct ContentViewEnvironment {
  var apps: AnyPublisher<[AppDetails], Never>
  var versionHistory: (AppDetails.ID) -> AnyPublisher<[Version], Never>
  var sortOrderState: AnyPublisher<SortOrderState, Never>
}

extension ContentViewEnvironment {
  var sortedApps: AnyPublisher<[AppDetails], Never> {
    apps
      .combineLatest(sortOrderState.removeDuplicates())
      .map { apps, sortOrderState in
        apps.applying(sortOrderState)
      }
      .eraseToAnyPublisher()
  }
}

struct ContentView: View {
  let environment: ContentViewEnvironment
  
  @State private var showSettings = false
  
  var body: some View {
    NavigationView {
      NewAppListView(
        environment: NewAppListViewEnvironment(
          apps: environment.sortedApps,
          versionHistory: environment.versionHistory
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
      NewSettingsView()
    }
  }
}
