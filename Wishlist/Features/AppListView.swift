import Combine
import ComposableArchitecture
import SwiftUI
import WishlistCore
import WishlistFoundation

struct AppDetailsContent: Equatable {
  let id: App.ID
  var versions: [Version]?
  var showVersionHistory: Bool
}

struct AppListState: Equatable {
  var apps: IdentifiedArrayOf<App>
  var sortOrder: SortOrder
  var theme: Theme
  var displayedAppDetails: AppDetailsContent?
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
  var loadApps: ([App.ID]) -> AnyPublisher<[AppSnapshot], Error>
  var versionHistory: (App.ID) -> [Version]
  var openURL: (URL) -> Void
  var saveTheme: (Theme) -> Void
  var recordDetailsViewed: (App.ID, Date) -> Void
}

struct AppListRowState: Identifiable {
  var id: App.ID { app.id }
  var app: App
  var sortOrder: SortOrder
  var details: AppDetailsContent?
  var isSelected: Bool { id == details?.id }

  var detailsState: AppDetailsState? {
    guard isSelected else {
      return nil
    }
    return AppDetailsState(app: app, versions: details?.versions, showVersionHistory: details?.showVersionHistory == true)
  }
}

extension AppListRowState: Equatable {
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.isSelected == rhs.isSelected && lhs.sortOrder == rhs.sortOrder && lhs.app == rhs.app
  }
}

enum AppListRowAction {
  case selected(Bool)
  case remove
  case openInNewWindow
  case viewInAppStore
  case details(AppDetailsAction)
}

private extension AppListState {
  var sortedApps: IdentifiedArrayOf<AppListRowState> {
    IdentifiedArray(
      apps.sorted(by: sortOrder).map {
        AppListRowState(app: $0, sortOrder: sortOrder, details: displayedAppDetails)
      }
    )
  }

  var appDetailsState: AppDetailsState? {
    get {
      guard let details = displayedAppDetails, let app = apps[id: details.id] else {
        return nil
      }
      return AppDetailsState(app: app, versions: details.versions, showVersionHistory: details.showVersionHistory)
    }
    set {
      guard let newValue = newValue else {
        return
      }
      apps[id: newValue.app.id] = newValue.app
      displayedAppDetails?.versions = newValue.versions
      displayedAppDetails?.showVersionHistory = newValue.showVersionHistory
    }
  }

  var addAppsState: AddAppsState {
    get { AddAppsState(apps: apps.elements) }
    set { apps = IdentifiedArrayOf(newValue.apps) }
  }

  var settingsState: SettingsState {
    get { SettingsState(theme: theme) }
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

    case let .app(id, .selected(true)):
      let now = environment.now()
      state.displayedAppDetails = .init(id: id, versions: nil, showVersionHistory: false)
      state.apps[id: id]?.lastViewed = now
      return .fireAndForget {
        environment.recordDetailsViewed(id, now)
      }

    case .app(_, .selected(false)):
      state.displayedAppDetails = nil
      return .none

    case let .app(id, .openInNewWindow):
      return .fireAndForget {
        let userActivity = NSUserActivity(activityType: ActivityIdentifier.details.rawValue)
        userActivity.userInfo = [ActivityIdentifier.UserInfoKey.id.rawValue: id]
        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: userActivity, options: nil)
      }

    case let .app(id, .viewInAppStore):
      guard let url = state.apps[id: id]?.url else {
        return .none
      }
      return .fireAndForget {
        environment.openURL(url)
      }

    case let .app(id, .remove):
      return Effect(value: .removeApps([id]))

    case let .app(id: _, action: .details(details)):
      return Effect(value: .appDetails(details))

    case .appDetails, .addApps, .settings:
      return .none
    }
  },
  appDetailsReducer.optional.pullback(
    state: \.appDetailsState,
    action: /AppListAction.appDetails,
    environment: { systemEnvironment in
      systemEnvironment.map {
        AppDetailsEnvironment(openURL: $0.openURL, versionHistory: $0.versionHistory)
      }
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
      SettingsEnvironment(saveTheme: $0.saveTheme, openURL: $0.openURL)
    }
  )
)

// MARK: - List

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
            ).onDelete {
              viewStore.send(.removeAppsAtIndexes($0))
            }
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
      }
        .onDrop(of: [UTI.url], delegate: URLDropDelegate { urls in
          viewStore.send(.addApps(.addAppsFromURLs(urls)))
        })
        .navigationViewStyle(StackNavigationViewStyle())
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
    ConnectedAppRow.ViewState(
      title: app.title,
      details: AppRow.Details(sortOrder: sortOrder, app: app),
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
        destination: IfLetStore(
          self.store.scope(state: \.detailsState, action: AppListRowAction.details),
          then: ConnectedAppDetailsView.init
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
  enum PriceChange {
    case same
    case decrease
    case increase
  }

  enum Details: Equatable {
    case price(String, change: PriceChange)
    case updated(Date, seen: Bool)
  }

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
      appDetailsView()
        .layoutPriority(1)
    }
  }

  private func appDetailsView() -> some View {
    switch details {
    case let .price(price, change):
      return ViewBuilder.buildEither(first:
        AppPriceDetails(price: price, change: change)
      ) as _ConditionalContent<AppPriceDetails, AppUpdateDetails>
    case let .updated(date, seen):
      return ViewBuilder.buildEither(second:
        AppUpdateDetails(date: date, seen: seen)
      ) as _ConditionalContent<AppPriceDetails, AppUpdateDetails>
    }
  }
}

private struct AppPriceDetails: View {
  let price: String
  let change: AppRow.PriceChange

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

private extension AppRow.Details {
  init(sortOrder: SortOrder, app: App) {
    switch sortOrder {
    case .updated:
      if let lastViewed = app.lastViewed {
        self = .updated(app.version.current.date, seen: lastViewed > app.version.current.date)
      } else {
        self = .updated(app.version.current.date, seen: app.firstAdded > app.version.current.date)
      }

    case .price, .title:
      self = .price(app.price.current.formatted, change: app.priceChange)
    }
  }
}

private extension App {
  var priceChange: AppRow.PriceChange {
    guard let previousPrice = price.previous else {
      return .same
    }

    if price.current == previousPrice {
      return .same
    }
    return price.current > previousPrice ? .increase : .decrease
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
  static var priceIncrease: Image { Image(systemName: "arrow.up") }
  static var priceDecrease: Image { Image(systemName: "arrow.down") }
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

extension Collection where Element == App {
  func sorted(by order: SortOrder) -> [App] {
    sorted {
      switch order {
      case .title: return $0.title < $1.title
      case .price: return $0.price.current < $1.price.current
      case .updated: return $0.version.current > $1.version.current
      }
    }
  }
}
