import Combine
import ComposableArchitecture
import SwiftUI
import Domain

struct AppListState: Equatable {
  var apps: IdentifiedArrayOf<AppDetails>
  var addAppsState: AddAppsState
  var sortOrderState: SortOrderState
  var settings: SettingsState
  var displayedAppDetails: AppDetailsContent?
  var isSettingsPresented: Bool
}

enum AppListAction {
  case displaySettings(Bool)
  case sort(SortOrderAction)
  case settings(SettingsAction)
  case addApps(AddAppsAction)
  case list(AppListContentAction)
}

struct AppListEnvironment {
  var loadApps: ([AppID]) -> AnyPublisher<[AppSummary], Error>
  var saveApps: ([AppDetails]) throws -> Void
  var deleteApps: ([AppID]) throws -> Void
  var versionHistory: (AppID) throws -> [Version]
  var saveNotifications: (AppID, Set<ChangeNotification>) throws -> Void
  var openURL: (URL) -> Void
  var saveSortOrder: (SortOrder) -> Void
  var saveTheme: (Theme) -> Void
  var recordDetailsViewed: (AppID, Date) throws -> Void
}

private extension AppListState {
  var listState: AppListContentState {
    get {
      AppListContentState(
        apps: apps,
        sortOrderState: sortOrderState,
        details: displayedAppDetails
      )
    }
    set {
      apps = newValue.apps
      sortOrderState = newValue.sortOrderState
      displayedAppDetails = newValue.details
    }
  }
}

let appListReducer = Reducer<AppListState, AppListAction, SystemEnvironment<AppListEnvironment>>.combine(
  addAppsReducer.pullback(
    state: \.addAppsState,
    action: /AppListAction.addApps,
    environment: { systemEnvironment in
      systemEnvironment.map {
        AddAppsEnvironment(
          loadApps: $0.loadApps,
          saveApps: $0.saveApps
        )
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
      return .fireAndForget {
        try? environment.deleteApps(ids)
      }

    case .addApps, .settings, .list, .sort:
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

extension Collection where Element == AppDetails {
  func applying(_ sorting: SortOrderState) -> [AppDetails] {
      filter { app in
        if sorting.sortOrder == .price && !sorting.configuration.price.includeFree {
          return app.price.current.value > 0
        }
        return true
      }
      .sorted(by: sorting)
  }

  private func sorted(by order: SortOrderState) -> [AppDetails] {
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
