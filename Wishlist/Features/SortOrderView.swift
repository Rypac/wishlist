import ComposableArchitecture
import SwiftUI
import WishlistFoundation

extension SortOrder {
  struct Configuration: Equatable {
    struct Price: Equatable {
      var sortLowToHigh: Bool
      var includeFree: Bool
    }

    struct Title: Equatable {
      var sortAToZ: Bool
    }

    struct Update: Equatable {
      var sortByMostRecent: Bool
    }

    var price: Price
    var title: Title
    var update: Update
  }
}

struct SortOrderState: Equatable {
  var sortOrder: SortOrder
  var configuration: SortOrder.Configuration
}

enum SortOrderAction {
  enum ConfigurePrice {
    case sortLowToHigh(Bool)
    case includeFree(Bool)
  }

  enum ConfigureTitle {
    case sortAToZ(Bool)
  }

  enum ConfigureUpdate {
    case sortByMostRecent(Bool)
  }

  case setSortOrder(SortOrder)
  case configurePrice(ConfigurePrice)
  case configureTitle(ConfigureTitle)
  case configureUpdate(ConfigureUpdate)
}

struct SortOrderEnvironment {
  var saveSortOrder: (SortOrder) -> Void
}

let sortOrderReducer = Reducer<SortOrderState, SortOrderAction, SortOrderEnvironment> { state, action, environment in
  switch action {
  case let .setSortOrder(sortOrder):
    state.sortOrder = sortOrder
    return .fireAndForget {
      environment.saveSortOrder(sortOrder)
    }

  case let .configurePrice(.sortLowToHigh(lowToHigh)):
    state.configuration.price.sortLowToHigh = lowToHigh
    return .none

  case let .configurePrice(.includeFree(includeFree)):
    state.configuration.price.includeFree = includeFree
    return .none

  case let .configureTitle(.sortAToZ(atoZ)):
    state.configuration.title.sortAToZ = atoZ
    return .none

  case let .configureUpdate(.sortByMostRecent(mostRecent)):
    state.configuration.update.sortByMostRecent = mostRecent
    return .none
  }
}

struct SortOrderView: View {
  let store: Store<SortOrderState, SortOrderAction>

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {
      SortOrderSelectionView(
        store: store.scope(
          state: \.sortOrder,
          action: SortOrderAction.setSortOrder
        )
      )
      IfLetStore(
        store.scope(
          state: { $0.sortOrder == .price ? $0.configuration.price : nil },
          action: SortOrderAction.configurePrice
        ),
        then: PriceSortOrderView.init
      )
      IfLetStore(
        store.scope(
          state: { $0.sortOrder == .title ? $0.configuration.title : nil },
          action: SortOrderAction.configureTitle
        ),
        then: TitleSortOrderView.init
      )
      IfLetStore(
        store.scope(
          state: { $0.sortOrder == .updated ? $0.configuration.update : nil },
          action: SortOrderAction.configureUpdate
        ),
        then: UpdatesSortOrderView.init
      )
    }.padding(.bottom)
  }
}

private struct SortOrderSelectionView: View {
  let store: Store<SortOrder, SortOrder>

  var body: some View {
    VStack(alignment: .leading) {
      Text("Sort By")
      WithViewStore(store) { viewStore in
        Picker("Sort By", selection: viewStore.binding(send: { $0 })) {
          ForEach(SortOrder.allCases, id: \.self) { sortOrder in
            Text(sortOrder.title).tag(sortOrder)
          }
        }.pickerStyle(SegmentedPickerStyle())
      }
    }
  }
}

private struct PriceSortOrderView: View {
  let store: Store<SortOrder.Configuration.Price, SortOrderAction.ConfigurePrice>

  var body: some View {
    Group {
      VStack(alignment: .leading) {
        Text("Price From")
        WithViewStore(store.scope(state: \.sortLowToHigh)) { viewStore in
          Picker("Options", selection: viewStore.binding(send: SortOrderAction.ConfigurePrice.sortLowToHigh)) {
            Text("Low to High").tag(true)
            Text("High to Low").tag(false)
          }.pickerStyle(SegmentedPickerStyle())
        }
      }
      WithViewStore(store.scope(state: \.includeFree)) { viewStore in
        Toggle(isOn: viewStore.binding(send: SortOrderAction.ConfigurePrice.includeFree)) {
          Text("Include Free Apps")
        }
      }
    }
  }
}

private struct TitleSortOrderView: View {
  let store: Store<SortOrder.Configuration.Title, SortOrderAction.ConfigureTitle>

  var body: some View {
    VStack(alignment: .leading) {
      Text("Title From")
      WithViewStore(store.scope(state: \.sortAToZ)) { viewStore in
        Picker("Options", selection: viewStore.binding(send: SortOrderAction.ConfigureTitle.sortAToZ)) {
          Text("A to Z").tag(true)
          Text("Z to A").tag(false)
        }.pickerStyle(SegmentedPickerStyle())
      }
    }
  }
}

private struct UpdatesSortOrderView: View {
  let store: Store<SortOrder.Configuration.Update, SortOrderAction.ConfigureUpdate>

  var body: some View {
    VStack(alignment: .leading) {
      Text("Updates By")
      WithViewStore(store.scope(state: \.sortByMostRecent)) { viewStore in
        Picker("Options", selection: viewStore.binding(send: SortOrderAction.ConfigureUpdate.sortByMostRecent)) {
          Text("Most Recent").tag(true)
          Text("Least Recent").tag(false)
        }.pickerStyle(SegmentedPickerStyle())
      }
    }
  }
}

private extension SortOrder {
  var title: String {
    switch self {
    case .price: return "Price"
    case .title: return "Title"
    case .updated: return "Updated"
    }
  }
}
