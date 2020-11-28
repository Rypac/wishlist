import ComposableArchitecture
import SwiftUI
import Core
import Domain
import ToolboxUI

struct AppSummary: Identifiable, Equatable {
  enum PriceChange {
    case same
    case decrease
    case increase
  }

  enum Details: Equatable {
    case price(String, change: PriceChange)
    case updated(Date, seen: Bool)
  }

  let id: Domain.App.ID
  let selected: Bool
  let title: String
  let details: Details
  let icon: URL
  let url: URL
}

enum AppListRowAction {
  case selected(Bool)
  case openInNewWindow
  case viewInAppStore
  case remove
}

struct AppListRowEnvironment {
  var openURL: (URL) -> Void
  var recordAppViewed: (Domain.App.ID, Date) -> Void
}

let appListRowReducer = Reducer<Domain.App, AppListRowAction, SystemEnvironment<AppListRowEnvironment>> { state, action, environment in
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

  case .openInNewWindow:
    let id = state.id
    return .fireAndForget {
      let scene = DetailsScene(id: id)
      UIApplication.shared.requestSceneSessionActivation(nil, userActivity: scene.userActivity, options: nil)
    }

  case .viewInAppStore:
    let url = state.url
    return .fireAndForget {
      environment.openURL(url)
    }

  case .remove:
    return .none
  }
}

struct AppListRowView: View {
  let store: Store<AppSummary, AppListRowAction>

  @State private var showShareSheet = false

  var body: some View {
    WithViewStore(store) { viewStore in
      AppRowContent(title: viewStore.title, details: viewStore.details, icon: viewStore.icon)
        .onDrag {
          NSItemProvider(url: viewStore.url, title: viewStore.title)
        }
        .contextMenu {
          Button(action: { viewStore.send(.openInNewWindow) }) {
            Text("Open in New Window")
            Image.window
          }.visible(on: .pad)
          Button(action: { viewStore.send(.viewInAppStore) }) {
            Text("View in App Store")
            Image.store
          }
          Button(action: { showShareSheet = true }) {
            Text("Share")
            Image.share
          }
          Button(action: { viewStore.send(.remove) }) {
            Text("Remove")
            Image.trash
          }
        }
        .sheet(isPresented: $showShareSheet) {
          ActivityView(
            showing: $showShareSheet,
            activityItems: [viewStore.url],
            applicationActivities: nil
          )
        }
    }
  }
}

private struct AppRowContent: View {
  let title: String
  let details: AppSummary.Details
  let icon: URL

  var body: some View {
    HStack {
      AppIcon(icon, width: 50)
      Text(title)
        .fontWeight(.medium)
        .layoutPriority(1)
      Spacer()

      switch details {
      case let .price(price, change):
        AppPriceDetails(price: price, change: change)
          .layoutPriority(1)
      case let .updated(date, seen):
        AppUpdateDetails(date: date, seen: seen)
          .layoutPriority(1)
      }
    }
  }
}

private struct AppPriceDetails: View {
  let price: String
  let change: AppSummary.PriceChange

  var body: some View {
    HStack {
      if change == .increase {
        Image.priceIncrease
      } else if change == .decrease {
        Image.priceDecrease
      }
      Text(price)
        .lineLimit(1)
        .multilineTextAlignment(.trailing)
    }
      .foregroundColor(color)
  }

  private var color: Color {
    switch change {
    case .same: return .primary
    case .decrease: return .green
    case .increase: return .red
    }
  }
}

private struct AppUpdateDetails: View {
  let date: Date
  let seen: Bool

  @Environment(\.updateDateFormatter) private var dateFormatter

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Text(dateFormatter.string(from: date))
        .lineLimit(1)
        .multilineTextAlignment(.trailing)

      if !seen {
        Circle()
          .foregroundColor(.blue)
          .frame(width: 15, height: 15)
          .offset(x: 8, y: -14)
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

private extension Image {
  static var share: Image { Image(systemName: "square.and.arrow.up") }
  static var store: Image { Image(systemName: "bag") }
  static var trash: Image { Image(systemName: "trash") }
  static var window: Image { Image(systemName: "square.grid.2x2") }
  static var priceIncrease: Image { Image(systemName: "arrow.up") }
  static var priceDecrease: Image { Image(systemName: "arrow.down") }
}
