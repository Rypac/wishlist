import Combine
import ComposableArchitecture
import SwiftUI
import WishlistCore
import WishlistFoundation

// MARK: - Composable Architecture

struct AppDetailsContent: Equatable {
  let id: App.ID
  var versions: [Version]?
  var showVersionHistory: Bool
}

private struct AppSummary: Identifiable, Equatable {
  enum PriceChange {
    case same
    case decrease
    case increase
  }

  enum Details: Equatable {
    case price(String, change: PriceChange)
    case updated(Date, seen: Bool)
  }

  let id: App.ID
  let title: String
  let details: Details
  let icon: URL
  let url: URL
}

struct AppListInternalState: Equatable {
  fileprivate var visibleApps: [App.ID] = []
}

struct AppListState: Equatable {
  var apps: IdentifiedArrayOf<App>
  var sortOrderState: SortOrderState
  var theme: Theme
  var internalState: AppListInternalState
  var displayedAppDetails: AppDetailsContent?
  var isSettingsPresented: Bool
}

enum AppListAction {
  case sortOrderUpdated
  case removeAppsAtIndexes(IndexSet)
  case removeApps([App.ID])
  case displaySettings(Bool)
  case sort(SortOrderAction)
  case app(id: App.ID, action: AppListRowAction)
  case appDetails(AppDetailsAction)
  case settings(SettingsAction)
  case addApps(AddAppsAction)
}

struct AppListEnvironment {
  var loadApps: ([App.ID]) -> AnyPublisher<[AppSnapshot], Error>
  var deleteApps: ([App.ID]) -> Void
  var versionHistory: (App.ID) -> [Version]
  var openURL: (URL) -> Void
  var saveSortOrder: (SortOrder) -> Void
  var saveTheme: (Theme) -> Void
  var recordDetailsViewed: (App.ID, Date) -> Void
}

enum AppListRowAction {
  case selected(Bool)
  case remove
  case openInNewWindow
  case viewInAppStore
}

private extension AppListState {
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

  func details(id: App.ID) -> AppDetailsState? {
    guard let details = displayedAppDetails, id == details.id, let app = apps[id: id] else {
      return nil
    }
    return AppDetailsState(app: app, versions: details.versions, showVersionHistory: details.showVersionHistory)
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
  ),
  sortOrderReducer.pullback(
    state: \.sortOrderState,
    action: /AppListAction.sort,
    environment: {
      SortOrderEnvironment(saveSortOrder: $0.saveSortOrder)
    }
  ),
  Reducer { state, action, environment in
    switch action {
    case let .displaySettings(isPresented):
      state.isSettingsPresented = isPresented
      return .none

    case let .removeAppsAtIndexes(indexes):
      let ids = indexes.map { state.internalState.visibleApps[$0] }
      return Effect(value: .removeApps(ids))

    case let .removeApps(ids):
      state.internalState.visibleApps.removeAll(where: ids.contains)
      state.apps.removeAll(where: { ids.contains($0.id) })
      return .fireAndForget {
        environment.deleteApps(ids)
      }

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
        userActivity.userInfo = [ActivityIdentifier.UserInfoKey.id.rawValue: id.rawValue]
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

    case .settings(.deleteAll):
      let ids = state.apps.map(\.id)
      return Effect(value: .removeApps(ids))

    case .sortOrderUpdated:
      state.internalState.visibleApps = state.apps.applying(state.sortOrderState)
      return .none

    case .sort, .addApps(.addAppsResponse(.success)):
      struct DebouceID: Hashable {}
      return Effect(value: .sortOrderUpdated)
        .debounce(id: DebouceID(), for: .milliseconds(400), scheduler: environment.mainQueue())

    case .appDetails, .addApps, .settings:
      return .none
    }
  }
)

// MARK: - App List

struct AppListView: View {
  let store: Store<AppListState, AppListAction>

  var body: some View {
    WithViewStore(store.scope(state: \.isSettingsPresented)) { viewStore in
      NavigationView {
        AppListContentView(store: self.store)
          .navigationBarTitle("Wishlist")
          .navigationBarItems(
            trailing: Button(action: {
              viewStore.send(.displaySettings(true))
            }) {
              HStack {
                Image.settings
                  .imageScale(.large)
                  .accessibility(label: Text("Settings"))
              }
              .frame(width: 24, height: 24)
            }
            .hoverEffect()
          )
          .sortingSheet(store: self.store.scope(state: \.sortOrderState, action: AppListAction.sort))
      }
      .sheet(isPresented: viewStore.binding(send: AppListAction.displaySettings)) {
        SettingsView(
          store: self.store.scope(
            state: \.settingsState,
            action: AppListAction.settings
          )
        )
      }
      .onDrop(of: [UTI.url], delegate: URLDropDelegate { urls in
        viewStore.send(.addApps(.addAppsFromURLs(urls)))
      })
      .navigationViewStyle(StackNavigationViewStyle())
    }
  }
}

private extension AppListState {
  func summary(id: App.ID, sortOrder: SortOrder) -> AppSummary {
    let app = apps[id: id]!
    return .init(
      id: app.id,
      title: app.title,
      details: .init(sortOrder: sortOrder, app: app),
      icon: app.icon.medium,
      url: app.url
    )
  }
}

private extension AppListState {
  var viewState: AppListContentView.ViewState {
    .init(sortOrder: sortOrderState.sortOrder, apps: internalState.visibleApps)
  }
}

private struct AppListContentView: View {
  struct ViewState: Equatable {
    let sortOrder: SortOrder
    let apps: [App.ID]
  }

  let store: Store<AppListState, AppListAction>

  var body: some View {
    WithViewStore(store.scope(state: \.viewState)) { viewStore in
      List {
        ForEach(viewStore.apps, id: \.self) { id in
          WithViewStore(self.store.scope(state: { $0.displayedAppDetails?.id == id })) { vs in
            NavigationLink(
              destination: IfLetStore(
                self.store.scope(state: { $0.details(id: id) }, action: AppListAction.appDetails),
                then: ConnectedAppDetailsView.init
              ),
              isActive: vs.binding(send: { .app(id: id, action: .selected($0)) })
            ) {
              ConnectedAppRow(
                store: self.store.scope(
                  state: { $0.summary(id: id, sortOrder: viewStore.sortOrder) },
                  action: { .app(id: id, action: $0) }
                )
              )
            }
          }
        }.onDelete {
          viewStore.send(.removeAppsAtIndexes($0))
        }
      }
    }
  }
}

// MARK: - App Row

private struct ConnectedAppRow: View {
  let store: Store<AppSummary, AppListRowAction>

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

private struct AppRow: View {
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

private extension AppSummary.Details {
  init(sortOrder: SortOrder, app: App) {
    switch sortOrder {
    case .updated:
      if let lastViewed = app.lastViewed {
        self = .updated(app.version.date, seen: lastViewed > app.version.date)
      } else if let firstAdded = app.firstAdded {
        self = .updated(app.version.date, seen: firstAdded > app.version.date)
      } else {
        self = .updated(app.version.date, seen: true)
      }

    case .price, .title:
      self = .price(app.price.current.formatted, change: app.priceChange)
    }
  }
}

private extension App {
  var priceChange: AppSummary.PriceChange {
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

private extension Collection where Element == App {
  func applying(_ sorting: SortOrderState) -> [App.ID] {
    sorted(by: sorting)
      .compactMap { app in
        if sorting.sortOrder == .price, !sorting.configuration.price.includeFree, app.price.current.value <= 0 {
          return nil
        }
        return app.id
      }
  }

  private func sorted(by order: SortOrderState) -> [App] {
    sorted {
      switch order.sortOrder {
      case .title:
        let aToZ = order.configuration.title.sortAToZ
        return aToZ ? $0.title < $1.title : $0.title > $1.title
      case .price:
        let lowToHigh = order.configuration.price.sortLowToHigh
        return lowToHigh ? $0.price.current < $1.price.current : $0.price.current > $1.price.current
      case .updated:
        let mostRecent = order.configuration.update.sortByMostRecent
        return mostRecent ? $0.version > $1.version : $0.version < $1.version
      }
    }
  }
}
