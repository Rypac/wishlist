import Combine
import ComposableArchitecture
import SwiftUI
import Domain

struct AppListInternalState: Equatable {
  fileprivate var appliedSortOrder: SortOrder
  fileprivate var visibleApps: [Domain.App.ID] = []

  init(sortOrder: SortOrder) {
    appliedSortOrder = sortOrder
  }
}

struct AppListState: Equatable {
  var apps: IdentifiedArrayOf<Domain.App>
  var sortOrderState: SortOrderState
  var settings: SettingsState
  var internalState: AppListInternalState
  var displayedAppDetails: AppDetailsContent?
  var isSettingsPresented: Bool
}

enum AppListAction {
  case sortOrderUpdated
  case displaySettings(Bool)
  case sort(SortOrderAction)
  case settings(SettingsAction)
  case addApps(AddAppsAction)
  case list(AppListContentAction)
}

struct AppListEnvironment {
  var loadApps: ([Domain.App.ID]) -> AnyPublisher<[AppSnapshot], Error>
  var deleteApps: ([Domain.App.ID]) -> Void
  var versionHistory: (Domain.App.ID) -> [Version]
  var saveNotifications: (Domain.App.ID, Set<ChangeNotification>) -> Void
  var openURL: (URL) -> Void
  var saveSortOrder: (SortOrder) -> Void
  var saveTheme: (Theme) -> Void
  var recordDetailsViewed: (Domain.App.ID, Date) -> Void
}

private extension AppListState {
  var addAppsState: AddAppsState {
    get { AddAppsState(apps: apps.elements) }
    set { apps = IdentifiedArrayOf(newValue.apps) }
  }

  var listState: AppListContentState {
    get {
      AppListContentState(
        sortOrder: internalState.appliedSortOrder,
        details: displayedAppDetails,
        visibleApps: internalState.visibleApps,
        apps: apps
      )
    }
    set {
      internalState.appliedSortOrder = newValue.sortOrder
      displayedAppDetails = newValue.details
      internalState.visibleApps = newValue.visibleApps
      apps = newValue.apps
    }
  }
}

let appListReducer = Reducer<AppListState, AppListAction, SystemEnvironment<AppListEnvironment>>.combine(
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
    state: \.settings,
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
  appListContentReducer.pullback(
    state: \.listState,
    action: /AppListAction.list,
    environment: { systemEnvironment in
      systemEnvironment.map {
        AppListContentEnvironment(
          openURL: $0.openURL,
          versionHistory: $0.versionHistory,
          deleteApps: $0.deleteApps,
          saveNotifications: $0.saveNotifications,
          recordAppViewed: $0.recordDetailsViewed
        )
      }
    }
  ),
  Reducer { state, action, environment in
    switch action {
    case let .displaySettings(isPresented):
      state.isSettingsPresented = isPresented
      return .none

    case .settings(.deleteAll):
      let ids = state.apps.map(\.id)
      return Effect(value: .list(.remove(ids)))

    case .sortOrderUpdated:
      state.internalState.appliedSortOrder = state.sortOrderState.sortOrder
      state.internalState.visibleApps = state.apps.applying(state.sortOrderState)
      return .none

    case .sort, .addApps(.addAppsResponse(.success)):
      struct DebouceID: Hashable {}
      return Effect(value: .sortOrderUpdated)
        .debounce(id: DebouceID(), for: .milliseconds(400), scheduler: environment.mainQueue())

    case .addApps, .settings, .list:
      return .none
    }
  }
)

struct AppListView: View {
  let store: Store<AppListState, AppListAction>

  var body: some View {
    WithViewStore(store.scope(state: \.isSettingsPresented)) { viewStore in
      NavigationView {
        AppListContentView(store: store.scope(state: \.listState, action: AppListAction.list))
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
          .sortingSheet(store: store.scope(state: \.sortOrderState, action: AppListAction.sort))
      }
      .sheet(isPresented: viewStore.binding(send: AppListAction.displaySettings)) {
        SettingsView(store: store.scope(state: \.settings, action: AppListAction.settings))
      }
      .onDrop(of: [UTI.url], delegate: URLDropDelegate { urls in
        viewStore.send(.addApps(.addAppsFromURLs(urls)))
      })
    }
  }
}

private extension Image {
  static var settings: Image { Image(systemName: "slider.horizontal.3") }
}

private extension Collection where Element == Domain.App {
  func applying(_ sorting: SortOrderState) -> [Domain.App.ID] {
    sorted(by: sorting)
      .compactMap { app in
        if sorting.sortOrder == .price, !sorting.configuration.price.includeFree, app.price.current.value <= 0 {
          return nil
        }
        return app.id
      }
  }

  private func sorted(by order: SortOrderState) -> [Domain.App] {
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
