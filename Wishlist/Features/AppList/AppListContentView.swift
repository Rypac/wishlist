import Combine
import ComposableArchitecture
import SwiftUI
import WishlistCore
import WishlistFoundation

struct AppDetailsContent: Equatable {
  let id: WishlistFoundation.App.ID
  var versions: [Version]?
  var showVersionHistory: Bool
}

struct AppListContentState: Equatable {
  var sortOrder: SortOrder
  var details: AppDetailsContent?
  var visibleApps: [WishlistFoundation.App.ID]
  var apps: IdentifiedArrayOf<WishlistFoundation.App>
}

enum AppListContentAction {
  case removeAtIndexes(IndexSet)
  case remove([WishlistFoundation.App.ID])
  case app(id: WishlistFoundation.App.ID, action: AppListRowAction)
  case details(AppDetailsAction)
}

struct AppListContentEnvironment {
  var openURL: (URL) -> Void
  var versionHistory: (WishlistFoundation.App.ID) -> [Version]
  var deleteApps: ([WishlistFoundation.App.ID]) -> Void
  var saveNotifications: (WishlistFoundation.App.ID, Set<ChangeNotification>) -> Void
  var recordAppViewed: (WishlistFoundation.App.ID, Date) -> Void
}

private extension AppListContentState {
  var detailsState: AppDetailsState? {
    get {
      guard let details = details, let app = apps[id: details.id] else {
        return nil
      }
      return AppDetailsState(app: app, versions: details.versions, showVersionHistory: details.showVersionHistory)
    }
    set {
      if let newValue = newValue {
        apps[id: newValue.app.id] = newValue.app
        details?.versions = newValue.versions
        details?.showVersionHistory = newValue.showVersionHistory
      }
    }
  }
}

let appListContentReducer = Reducer<AppListContentState, AppListContentAction, SystemEnvironment<AppListContentEnvironment>>.combine(
  appListRowReducer.forEach(
    state: \.apps,
    action: /AppListContentAction.app,
    environment: { systemEnvironment in
      systemEnvironment.map {
        AppListRowEnvironment(openURL: $0.openURL, recordAppViewed: $0.recordAppViewed)
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
      if selected {
        state.details = AppDetailsContent(id: id, versions: nil, showVersionHistory: false)
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
  func summary(_ id: WishlistFoundation.App.ID) -> AppSummary? {
    guard let app = apps[id: id] else {
      return nil
    }
    return AppSummary(
      id: app.id,
      selected: details?.id == id,
      title: app.title,
      details: .init(sortOrder: sortOrder, app: app),
      icon: app.icon.medium,
      url: app.url
    )
  }
}

struct AppListContentView: View {
  let store: Store<AppListContentState, AppListContentAction>

  var body: some View {
    WithViewStore(store.scope(state: \.visibleApps)) { viewStore in
      List {
        ForEach(viewStore.state, id: \.self) { id in
          IfLetStore(
            store.scope(state: { $0.summary(id) }, action: { .app(id: id, action: $0) })
          ) { store in
            WithViewStore(store.scope(state: \.selected)) { viewStore in
              NavigationLink(
                destination: IfLetStore(
                  self.store.scope(state: \.detailsState, action: AppListContentAction.details),
                  then: ConnectedAppDetailsView.init
                ),
                tag: id,
                selection: viewStore.binding(get: { $0 ? id : nil }, send: { .selected($0 != nil) })
              ) {
                AppListRowView(store: store)
              }
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
  init(sortOrder: SortOrder, app: WishlistFoundation.App) {
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

private extension WishlistFoundation.App {
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
