import ComposableArchitecture
import SwiftUI
import WishlistCore
import WishlistFoundation

struct AppListContentState: Equatable {
  var sortOrder: SortOrder
  var details: AppDetailsState?
  var visibleApps: [App.ID]
  var apps: IdentifiedArrayOf<App>
}

enum AppListContentAction {
  case removeAtIndexes(IndexSet)
  case remove([App.ID])
  case app(id: App.ID, action: AppListItemAction)
  case details(AppDetailsAction)
}

struct AppListContentEnvironment {
  var openURL: (URL) -> Void
  var versionHistory: (App.ID) -> [Version]
  var deleteApps: ([App.ID]) -> Void
  var saveNotifications: (App.ID, Set<ChangeNotification>) -> Void
  var recordAppViewed: (App.ID, Date) -> Void
}

private extension AppListContentState {
  var detailsState: AppDetailsState? {
    get { details }
    set {
      details = newValue
      if let app = newValue?.app {
        apps[id: app.id] = app
      }
    }
  }
}

let appListContentReducer = Reducer<AppListContentState, AppListContentAction, SystemEnvironment<AppListContentEnvironment>>.combine(
  appListItemReducer.forEach(
    state: \.apps,
    action: /AppListContentAction.app,
    environment: { systemEnvironment in
      systemEnvironment.map {
        AppListItemEnvironment(recordAppViewed: $0.recordAppViewed)
      }
    }
  ),
  appDetailsReducer.optional.pullback(
    state: \.detailsState,
    action: /AppListContentAction.details,
    environment: { systemEnvironment in
      systemEnvironment.map {
        AppDetailsEnvironment(
          openURL: $0.openURL,
          versionHistory: $0.versionHistory,
          saveNotifications: $0.saveNotifications
        )
      }
    }
  ),
  Reducer { state, action, environment in
    switch action {
    case let .removeAtIndexes(indexes):
      let ids = indexes.map { state.visibleApps[$0] }
      return Effect(value: .remove(ids))

    case let .remove(ids):
      state.visibleApps.removeAll(where: ids.contains)
      state.apps.removeAll(where: { ids.contains($0.id) })
      return .fireAndForget {
        environment.deleteApps(ids)
      }

    case let .app(id, .selected(selected)):
      if selected, let app = state.apps[id: id] {
        state.details = AppDetailsState(app: app, versions: nil, showVersionHistory: false)
      } else {
        state.details = nil
      }
      return .none

    case let .app(id, .remove):
      return Effect(value: .remove([id]))

    case .app, .details:
      return .none
    }
  }
)

private extension AppListContentState {
  var summaries: IdentifiedArrayOf<AppSummary> {
    IdentifiedArrayOf(
      visibleApps.compactMap { id in
        guard let app = apps[id: id] else {
          return nil
        }
        return AppSummary(
          id: app.id,
          selected: details?.app.id == id,
          title: app.title,
          details: .init(sortOrder: sortOrder, app: app),
          icon: app.icon.medium,
          url: app.url
        )
      }
    )
  }
}

private extension AppSummary {
  struct ViewState: Equatable {
    let id: App.ID
    let selected: Bool
  }

  var view: ViewState {
    .init(id: id, selected: selected)
  }
}

struct AppListContentView: View {
  let store: Store<AppListContentState, AppListContentAction>

  var body: some View {
    WithViewStore(store.stateless) { viewStore in
      List {
        ForEachStore(self.store.scope(state: \.summaries, action: AppListContentAction.app)) { eachStore in
          WithViewStore(eachStore.scope(state: \.view)) { viewStore in
            NavigationLink(
              destination: IfLetStore(
                self.store.scope(state: \.details, action: AppListContentAction.details),
                then: ConnectedAppDetailsView.init
              ),
              tag: viewStore.id,
              selection: viewStore.binding(
                get: { $0.selected ? $0.id : nil },
                send: { .selected($0 != nil) }
              )
            ) {
              AppListRow(store: eachStore)
            }
          }
        }.onDelete {
          viewStore.send(.removeAtIndexes($0))
        }
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
