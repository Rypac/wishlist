import ComposableArchitecture
import SwiftUI
import WishlistCore
import WishlistFoundation

enum AppListItemAction {
  case selected(Bool)
  case openInNewWindow
  case viewInAppStore
  case remove
}

struct AppListItemEnvironment {
  var recordAppViewed: (App.ID, Date) -> Void
}

let appListItemReducer = Reducer<App, AppListItemAction, SystemEnvironment<AppListItemEnvironment>> { state, action, environment in
  switch action {
  case let .selected(selected):
    guard selected else {
      return .none
    }

    let id = state.id
    let now = environment.now()
    state.lastViewed = now
    return .fireAndForget {
      environment.recordAppViewed(id, now)
    }

  case .openInNewWindow, .viewInAppStore, .remove:
    return .none
  }
}

struct AppListRow: View {
  let store: Store<AppSummary, AppListItemAction>

  @State private var showShareSheet = false

  var body: some View {
    WithViewStore(store) { viewStore in
      AppRow(title: viewStore.title, details: viewStore.details, icon: viewStore.icon)
        .onDrag {
          NSItemProvider(url: viewStore.url, title: viewStore.title)
        }
        .contextMenu {
          Button(action: { viewStore.send(.openInNewWindow) }) {
            Text("Open in New Window")
            Image(systemName: "square.grid.2x2")
          }.visible(on: .pad)
          Button(action: { viewStore.send(.viewInAppStore) }) {
            Text("View in App Store")
            Image(systemName: "bag")
          }
          Button(action: { self.showShareSheet = true }) {
            Text("Share")
            Image(systemName: "square.and.arrow.up")
          }
          Button(action: { viewStore.send(.remove) }) {
            Text("Remove")
            Image(systemName: "trash")
          }
        }
        .sheet(isPresented: self.$showShareSheet) {
          ActivityView(
            showing: self.$showShareSheet,
            activityItems: [viewStore.url],
            applicationActivities: nil
          )
        }
    }
  }
}

private extension NSItemProvider {
  convenience init(url: URL, title: String) {
    self.init(object: URLItemProvider(url: url, title: title))
    self.suggestedName = title
  }
}
