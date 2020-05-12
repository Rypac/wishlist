import Combine
import ComposableArchitecture
import SwiftUI
import WishlistCore
import WishlistModel

struct AppListState: Equatable {
  var apps: [App]
  var sortOrder: SortOrder
  var theme: Theme
  var displayedAppDetailsID: App.ID? = nil
  var isSettingsSheetPresented: Bool = false
  var isSortOrderSheetPresented: Bool = false
}

enum AppListAction {
  case removeAppsAtIndexes(IndexSet)
  case removeApps([App.ID])
  case setSortOrder(SortOrder)
  case setSortOrderSheet(isPresented: Bool)
  case setSettingsSheet(isPresented: Bool)
  case app(id: App.ID, action: AppListRowAction)
  case appDetails(AppDetailsAction)
  case settings(SettingsAction)
  case addApps(AddAppsAction)
}

struct AppListEnvironment {
  var loadApps: ([App.ID]) -> AnyPublisher<[App], Error>
  var openURL: (URL) -> Void
  var saveTheme: (Theme) -> Void
}

struct AppListRowState: Identifiable, Equatable {
  var id: App.ID { app.id }
  var app: App
  var sortOrder: SortOrder
  var isSelected: Bool

  var detailsState: AppDetailsState {
    AppDetailsState(app: app)
  }
}

enum AppListRowAction {
  case selected(Bool)
  case remove
  case openInNewWindow
  case viewInAppStore
  case viewDetails(AppDetailsAction)
}

private extension AppListState {
  var sortedApps: IdentifiedArrayOf<AppListRowState> {
    IdentifiedArray(
      apps.sorted(by: sortOrder).map {
        AppListRowState(app: $0, sortOrder: sortOrder, isSelected: $0.id == displayedAppDetailsID)
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

  var settingsState: SettingsState {
    get { .init(theme: theme) }
    set { theme = newValue.theme }
  }
}

let appListReducer = Reducer<AppListState, AppListAction, SystemEnvironment<AppListEnvironment>>.combine(
  Reducer { state, action, environment in
    switch action {
    case let .setSortOrderSheet(isPresented):
      state.isSortOrderSheetPresented = isPresented
      return .none

    case let .setSettingsSheet(isPresented):
      state.isSettingsSheetPresented = isPresented
      return .none

    case let .removeAppsAtIndexes(indexes):
      let apps = state.apps.sorted(by: state.sortOrder)
      let ids = indexes.map { apps[$0].id }
      return Effect(value: .removeApps(ids))

    case let .removeApps(ids):
      state.apps.removeAll(where: { ids.contains($0.id) })
      return .none

    case let .setSortOrder(sortOrder):
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

    case let .app(id, .remove):
      return Effect(value: .removeApps([id]))

    case .appDetails, .app, .addApps, .settings:
      return .none
    }
  },
  appDetailsReducer.optional.pullback(
    state: \.appDetailsState,
    action: /AppListAction.appDetails,
    environment: {
      AppDetailsEnvironment(openURL: $0.openURL)
    }
  ),
  addAppsReducer.pullback(
    state: \.addAppsState,
    action: /AppListAction.addApps,
    environment: { systemEnvironment in
      systemEnvironment.map {
        AddAppsEnvironment(loadApps: $0.loadApps)
      }
    }
  ),
  settingsReducer.pullback(
    state: \.settingsState,
    action: /AppListAction.settings,
    environment: {
      SettingsEnvironment(saveTheme: $0.saveTheme)
    }
  )
)

// MARK: - List

struct AppListView: View {
  let store: Store<AppListState, AppListAction>

  var body: some View {
    WithViewStore(store.scope(state: \.theme)) { viewStore in
      NavigationView {
        ZStack {
          List {
            ForEachStore(
              self.store.scope(state: \.sortedApps, action: AppListAction.app),
              content: ConnectedAppRow.init
            ).onDelete { viewStore.send(.removeAppsAtIndexes($0)) }
          }
          SettingsSheet(store: self.store)
          SortOrderSheet(store: self.store.scope(state: \.isSortOrderSheetPresented))
        }
        .navigationBarTitle("Wishlist")
        .navigationBarItems(
          leading: Button(action: {
            viewStore.send(.setSettingsSheet(isPresented: true))
          }) {
            HStack {
              Image.settings
                .imageScale(.large)
                .accessibility(label: Text("Settings"))
            }
            .frame(width: 24, height: 24)
          }.hoverEffect(),
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
      }.onDrop(of: [UTI.url], delegate: URLDropDelegate { urls in
        viewStore.send(.addApps(.addAppsFromURLs(urls)))
      })
    }
  }
}

private struct SettingsSheet: View {
  let store: Store<AppListState, AppListAction>

  var body: some View {
    WithViewStore(store.scope(state: \.isSettingsSheetPresented)) { viewStore in
      Color.clear
        .sheet(
          isPresented: viewStore.binding(send: AppListAction.setSettingsSheet)
        ) {
          SettingsView(
            store: self.store.scope(
              state: \.settingsState,
              action: AppListAction.settings
            )
          )
        }
    }
  }
}

private struct SortOrderSheet: View {
  let store: Store<Bool, AppListAction>

  var body: some View {
    WithViewStore(store) { viewStore in
      Color.clear
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

// MARK: - Row

private extension AppListRowState {
  var view: ConnectedAppRow.ViewState {
    .init(
      title: app.title,
      details: sortOrder == .updated ? .updated(app.updateDate) : .price(app.price.formatted),
      icon: app.icon.medium,
      url: app.url,
      isSelected: isSelected
    )
  }
}

private struct ConnectedAppRow: View {
  struct ViewState: Equatable {
    let title: String
    let details: AppRow.Details
    let icon: URL
    let url: URL
    let isSelected: Bool
  }

  let store: Store<AppListRowState, AppListRowAction>

  @State private var showShareSheet = false

  var body: some View {
    WithViewStore(store.scope(state: \.view)) { viewStore in
      NavigationLink(
        destination: ConnectedAppDetailsView(
          store: self.store.scope(state: \.detailsState, action: AppListRowAction.viewDetails)
        ),
        isActive: viewStore.binding(get: \.isSelected, send: AppListRowAction.selected)
      ) {
        AppRow(title: viewStore.title, details: viewStore.details, icon: viewStore.icon)
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
            Button(action: { self.showShareSheet = true }) {
              Text("Share")
              Image.share
            }
            Button(action: { viewStore.send(.remove) }) {
              Text("Remove")
              Image.trash
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
  enum Details: Equatable {
    case price(String)
    case updated(Date)
  }

  @Environment(\.updateDateFormatter) private var dateFormatter

  let title: String
  let details: Details
  let icon: URL

  var body: some View {
    HStack {
      AppIcon(icon, width: 50)
      Text(title)
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
    switch details {
    case let .price(price): return price
    case let .updated(date): return dateFormatter.string(from: date)
    }
  }
}

// MARK: - Extensions

private extension Image {
  static var settings: Image { Image(systemName: "slider.horizontal.3") }
  static var sort: Image { Image(systemName: "arrow.up.arrow.down") }
  static var share: Image { Image(systemName: "square.and.arrow.up") }
  static var store: Image { Image(systemName: "bag") }
  static var trash: Image { Image(systemName: "trash") }
  static var window: Image { Image(systemName: "square.grid.2x2") }
}

extension NSItemProvider {
  convenience init(url: URL, title: String) {
    self.init(object: URLItemProvider(url: url, title: title))
    self.suggestedName = title
  }
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
