import Combine
import ComposableArchitecture
import SwiftUI
import WishlistData

// MARK: - Composable Architecture

struct AppListState: Equatable {
  var apps: [App]
  var sortOrder: SortOrder
  var displayedAppDetailsID: App.ID? = nil
  var isSortOrderSheetPresented: Bool = false
}

enum AppListAction {
  case removeAppsAtIndexes(IndexSet)
  case removeApps([App.ID])
  case setSortOrder(SortOrder)
  case setSortOrderSheet(isPresented: Bool)
  case app(id: App.ID, action: AppSummaryAction)
  case appDetails(AppDetailsAction)
  case addApps(AddAppsAction)
}

struct AppListEnvironment {
  var loadApps: ([App.ID]) -> AnyPublisher<[App], Error>
  var openURL: (URL) -> Void
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

struct AppSummaryState: Identifiable, Equatable {
  var id: App.ID { app.id }
  var app: App
  var sortOrder: SortOrder
  var isSelected: Bool

  var detailsState: AppDetailsState {
    AppDetailsState(app: app)
  }
}

enum AppSummaryAction {
  case selected(Bool)
  case openInNewWindow
  case viewInAppStore
  case viewDetails(AppDetailsAction)
}

private extension AppListState {
  var sortedApps: IdentifiedArrayOf<AppSummaryState> {
    IdentifiedArray(
      apps.sorted(by: sortOrder).map {
        AppSummaryState(app: $0, sortOrder: sortOrder, isSelected: $0.id == displayedAppDetailsID)
      }
    )
  }

  var appDetailsState: AppDetailsState? {
    get {
      guard let id = displayedAppDetailsID, let app = apps.first(where: { $0.id == id }) else {
        return nil
      }
      return AppDetailsState(app: app)
    }
    set {}
  }

  var addAppsState: AddAppsState {
    get { .init(apps: apps) }
    set { apps = newValue.apps }
  }
}

let appListReducer = Reducer<AppListState, AppListAction, AppListEnvironment>.combine(
  Reducer { state, action, environment in
    switch action {
    case .setSortOrderSheet(let isPresented):
      state.isSortOrderSheetPresented = isPresented
      return .none
    case .removeAppsAtIndexes(let indexes):
      let apps = state.apps.sorted(by: state.sortOrder)
      let ids = indexes.map { apps[$0].id }
      return Effect(value: .removeApps(ids))
    case .removeApps(let ids):
      state.apps.removeAll(where: { ids.contains($0.id) })
      return .none
    case .setSortOrder(let sortOrder):
      state.sortOrder = sortOrder
      return .none
    case let .app(id, .selected(selected)):
      state.displayedAppDetailsID = selected ? id : nil
      return .none
    case let .app(id, .openInNewWindow):
      return .fireAndForget {
        let userActivity = NSUserActivity(activityType: ActivityIdentifier.details.rawValue)
        userActivity.userInfo = [ActivityIdentifier.UserInfoKey.id.rawValue: id]
        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: userActivity, options: nil)
      }
    case let .app(id, .viewInAppStore):
      guard let url = state.apps.first(where: { $0.id == id })?.url else {
        return .none
      }
      return .fireAndForget {
        environment.openURL(url)
      }
    case .appDetails, .app, .addApps:
      return .none
    }
  },
  appDetailsReducer.optional.pullback(
    state: \.appDetailsState,
    action: /AppListAction.appDetails,
    environment: { AppDetailsEnvironment(openURL: $0.openURL) }
  ),
  addAppsReducer.pullback(
    state: \.addAppsState,
    action: /AppListAction.addApps,
    environment: {
      AddAppsEnvironment(loadApps: $0.loadApps, mainQueue: $0.mainQueue)
    }
  )
)

// MARK: - View

struct AppListView: View {
  let store: Store<AppListState, AppListAction>

  var body: some View {
    WithViewStore(store.stateless) { viewStore in
      NavigationView {
        ZStack {
          List {
            ForEachStore(
              self.store.scope(state: \.sortedApps, action: AppListAction.app),
              content: ConnectedAppRow.init
            ).onDelete { viewStore.send(.removeAppsAtIndexes($0)) }
          }
          SortOrderSelector(store: self.store.scope(state: \.isSortOrderSheetPresented))
        }.navigationBarTitle("Wishlist")
      }.onDrop(of: [UTI.url], delegate: URLDropDelegate { urls in
        viewStore.send(.addApps(.addAppsFromURLs(urls)))
      })
    }
  }
}

private struct SortOrderSelector: View {
  let store: Store<Bool, AppListAction>

  var body: some View {
    WithViewStore(store) { viewStore in
      EmptyView()
        .navigationBarItems(
          trailing: Button(action: {
            viewStore.send(.setSortOrderSheet(isPresented: true))
          }) {
            HStack {
              Image.sort
                .imageScale(.large)
                .accessibility(label: Text("Sort By"))
            }
            .frame(width: 24, height: 24)
          }.hoverEffect()
        )
        .actionSheet(
          isPresented: viewStore.binding(send: AppListAction.setSortOrderSheet)
        ) {
          var buttons = SortOrder.allCases.map { sortOrder in
            Alert.Button.default(Text(sortOrder.title)) {
              viewStore.send(.setSortOrder(sortOrder))
            }
          }
          buttons.append(.cancel())
          return ActionSheet(title: Text("Sort By"), buttons: buttons)
        }
    }
  }
}

private extension AppSummaryState {
  var view: ConnectedAppRow.ViewState {
    .init(url: app.url, isSelected: isSelected)
  }

  var contentView: ConnectedAppRow.ContentViewState {
    .init(app: app, sortOrder: sortOrder)
  }
}

private struct ConnectedAppRow: View {
  struct ViewState: Equatable {
    let url: URL
    let isSelected: Bool
  }

  struct ContentViewState: Equatable {
    let app: App
    let sortOrder: SortOrder
  }

  let store: Store<AppSummaryState, AppSummaryAction>

  @State private var showShareSheet = false

  var body: some View {
    WithViewStore(store.scope(state: \.view)) { viewStore in
      NavigationLink(
        destination: ConnectedAppDetailsView(
          store: self.store.scope(state: \.detailsState, action: AppSummaryAction.viewDetails)
        ),
        isActive: viewStore.binding(get: \.isSelected, send: AppSummaryAction.selected)
      ) {
        WithViewStore(self.store.scope(state: \.contentView).actionless) { viewStore in
          AppRow(app: viewStore.app, sortOrder: viewStore.sortOrder)
            .onDrag { NSItemProvider(app: viewStore.app) }
        }
          .contextMenu {
            Button(action: { viewStore.send(.openInNewWindow) }) {
              Text("Open in New Window")
              Image.window
            }.visible(on: .iPad)
            Button(action: { viewStore.send(.viewInAppStore) }) {
              Text("View in App Store")
              Image.store
            }
            Button(action: { self.showShareSheet = true }) {
              Text("Share")
              Image.share
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
}

private struct AppRow: View {
  @Environment(\.updateDateFormatter) private var dateFormatter

  let app: App
  let sortOrder: SortOrder

  var body: some View {
    HStack {
      AppIcon(app.icon.medium, width: 50)
      Text(app.title)
        .fontWeight(.medium)
        .layoutPriority(1)
      Spacer()
      Text(appDetails)
        .lineLimit(1)
        .multilineTextAlignment(.trailing)
        .layoutPriority(1)
    }
  }

  private var appDetails: String {
    if sortOrder == .updated {
      return dateFormatter.string(from: app.updateDate)
    }
    return app.price.formatted
  }
}

private extension Image {
  static var sort: Image { Image(systemName: "arrow.up.arrow.down") }
  static var share: Image { Image(systemName: "square.and.arrow.up") }
  static var store: Image { Image(systemName: "bag") }
  static var window: Image { Image(systemName: "square.grid.2x2") }
}

private extension SortOrder {
  var title: String {
    switch self {
    case .price: return "Price"
    case .title: return "Title"
    case .updated: return "Recently Updated"
    }
  }
}

extension Array where Element == App {
  func sorted(by order: SortOrder) -> [App] {
    sorted {
      switch order {
      case .title: return $0.title < $1.title
      case .price: return $0.price.value < $1.price.value
      case .updated: return $0.updateDate > $1.updateDate
      }
    }
  }
}
