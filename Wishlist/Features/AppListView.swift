import Combine
import ComposableArchitecture
import SwiftUI
import WishlistData

struct AppListState: Equatable {
  var apps: [App]
  var sortOrder: SortOrder
  var displayedAppDetailsID: Int? = nil
  var isSortOrderSheetPresented: Bool = false
}

enum AppListAction {
  case addApps([URL])
  case addAppsResponse(Result<[App], Error>)
  case removeApps(IndexSet)
  case showAppDetails(id: Int?)
  case setSortOrder(SortOrder)
  case setSortOrderSheet(isPresented: Bool)
}

struct AppListEnvironment {
  let repository: AppRepository
  var persistSortOrder: (SortOrder) -> Void
  var loadApps: ([URL]) -> AnyPublisher<[App], Error>
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

let appListReducer = Reducer<AppListState, AppListAction, AppListEnvironment> { state, action, environment in
  switch action {
  case .setSortOrderSheet(let isPresented):
    state.isSortOrderSheetPresented = isPresented
    return .none
  case .addAppsResponse(let result):
    guard case .success(let apps) = result, !apps.isEmpty else {
      return .none
    }
    state.apps.append(contentsOf: apps)
    state.apps.sort(by: state.sortOrder)
    return .fireAndForget {
      try? environment.repository.add(apps)
    }
  case .addApps(let urls):
    return environment.loadApps(urls)
      .receive(on: environment.mainQueue)
      .catchToEffect()
      .map(AppListAction.addAppsResponse)
  case .removeApps(let indexes):
    let originalApps = state.apps
    state.apps.remove(atOffsets: indexes)
    let deletedApps = originalApps.filter { !state.apps.contains($0) }
    return .fireAndForget {
      try? environment.repository.delete(deletedApps)
    }
  case .setSortOrder(let sortOrder):
    state.sortOrder = sortOrder
    state.apps.sort(by: sortOrder)
    return .fireAndForget {
      environment.persistSortOrder(sortOrder)
    }
  case .showAppDetails(let id):
    state.displayedAppDetailsID = id
    return .none
  }
}

struct AppListView: View {
  let store: Store<AppListState, AppListAction>

  var body: some View {
    WithViewStore(store) { viewStore in
      NavigationView {
        List {
          ForEach(viewStore.apps) { app in
            NavigationLink(
              destination: AppDetailsView(app: app),
              isActive: viewStore.binding(
                get: { $0.displayedAppDetailsID == app.id },
                send: { show in .showAppDetails(id: show ? app.id : nil) }
              )
            ) {
              AppRow(app: app, sortOrder: viewStore.sortOrder)
            }
          }.onDelete { indexes in
            viewStore.send(.removeApps(indexes))
          }
        }
          .navigationBarTitle("Wishlist")
          .navigationBarItems(
            trailing: Button(action: { viewStore.send(.setSortOrderSheet(isPresented: true)) }) {
              HStack {
                Image.sort
                  .imageScale(.large)
                  .accessibility(label: Text("Sort By"))
              }
              .frame(width: 24, height: 24)
            }.hoverEffect()
          )
          .actionSheet(
            isPresented: viewStore.binding(
              get: \.isSortOrderSheetPresented,
              send: AppListAction.setSortOrderSheet
            )
          ) {
            var buttons = SortOrder.allCases.map { sortOrder in
              Alert.Button.default(Text(sortOrder.title)) {
                viewStore.send(.setSortOrder(sortOrder))
              }
            }
            buttons.append(.cancel())
            return ActionSheet(title: Text("Sort By"), buttons: buttons)
          }
      }.onDrop(of: [UTI.url], delegate: URLDropDelegate { urls in
        viewStore.send(.addApps(urls))
      })
    }
  }
}

private struct AppRow: View {
  @State private var showShareSheet = false

  let app: App
  let sortOrder: SortOrder

  var body: some View {
    AppRowContent(app: app, sortOrder: sortOrder)
      .onDrag { NSItemProvider(app: self.app) }
      .contextMenu {
        Button(action: {
          let userActivity = NSUserActivity(activityType: ActivityIdentifier.details.rawValue)
          userActivity.userInfo = [ActivityIdentifier.UserInfoKey.id.rawValue: self.app.id]
          UIApplication.shared.requestSceneSessionActivation(nil, userActivity: userActivity, options: nil)
        }) {
          Text("Open in New Window")
          Image.window
        }.visible(on: .iPad)
        Button(action: { self.showShareSheet = true }) {
          Text("Share")
          Image.share
        }
      }
      .sheet(isPresented: self.$showShareSheet) {
        ActivityView(showing: self.$showShareSheet, activityItems: [self.app.url], applicationActivities: nil)
      }
  }
}

private struct AppRowContent: View {
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
    return app.formattedPrice
  }
}

private extension Image {
  static var sort: Image { Image(systemName: "arrow.up.arrow.down") }
  static var share: Image { Image(systemName: "square.and.arrow.up") }
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
  mutating func sort(by order: SortOrder) {
    sort {
      switch order {
      case .title: return $0.title < $1.title
      case .price: return $0.price < $1.price
      case .updated: return $0.updateDate > $1.updateDate
      }
    }
  }
}
