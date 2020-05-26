import ComposableArchitecture
import SwiftUI
import WishlistFoundation

struct SortOrderState: Equatable {
  var sortOrder: SortOrder
  var sortUpdatesByMostRecent: Bool = true
  var sortPriceLowToHigh: Bool = true
  var sortTitleAToZ: Bool = true
}

enum SortOrderAction {
  case setSortOrder(SortOrder)
  case sortPriceFromLowToHigh(Bool)
  case sortTitleFromAToZ(Bool)
  case sortUpdatesByMostRecent(Bool)
}

struct SortOrderEnvironment {}

let sortOrderReducer = Reducer<SortOrderState, SortOrderAction, SortOrderEnvironment> { state, action, environment in
  switch action {
  case let .setSortOrder(sortOrder):
    state.sortOrder = sortOrder
    return .none

  case let .sortPriceFromLowToHigh(lowToHigh):
    state.sortPriceLowToHigh = lowToHigh
    return .none

  case let .sortTitleFromAToZ(atoZ):
    state.sortTitleAToZ = atoZ
    return .none

  case let .sortUpdatesByMostRecent(mostRecent):
    state.sortUpdatesByMostRecent = mostRecent
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
          state: { $0.sortOrder == .price ? $0.sortPriceLowToHigh : nil },
          action: SortOrderAction.sortPriceFromLowToHigh
        ),
        then: PriceSortOrderView.init
      )
      IfLetStore(
        store.scope(
          state: { $0.sortOrder == .title ? $0.sortTitleAToZ : nil },
          action: SortOrderAction.sortTitleFromAToZ
        ),
        then: TitleSortOrderView.init
      )
      IfLetStore(
        store.scope(
          state: { $0.sortOrder == .updated ? $0.sortUpdatesByMostRecent : nil },
          action: SortOrderAction.sortUpdatesByMostRecent
        ),
        then: UpdatesSortOrderView.init
      )
    }
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
  let store: Store<Bool, Bool>

  var body: some View {
    VStack(alignment: .leading) {
      Text("Price From")
      WithViewStore(store) { viewStore in
        Picker("Options", selection: viewStore.binding(send: { $0 })) {
          ForEach([true, false], id: \.self) { lowToHigh in
            Text(lowToHigh ? "Low to High" : "High to Low").tag(lowToHigh)
          }
        }.pickerStyle(SegmentedPickerStyle())
      }
    }
  }
}

private struct TitleSortOrderView: View {
  let store: Store<Bool, Bool>

  var body: some View {
    VStack(alignment: .leading) {
      Text("Title From")
      WithViewStore(store) { viewStore in
        Picker("Options", selection: viewStore.binding(send: { $0 })) {
          ForEach([true, false], id: \.self) { aToZ in
            Text(aToZ ? "A to Z" : "Z to A").tag(aToZ)
          }
        }.pickerStyle(SegmentedPickerStyle())
      }
    }
  }
}

private struct UpdatesSortOrderView: View {
  let store: Store<Bool, Bool>

  var body: some View {
    VStack(alignment: .leading) {
      Text("Updates By")
      WithViewStore(store) { viewStore in
        Picker("Options", selection: viewStore.binding(send: { $0 })) {
          ForEach([true, false], id: \.self) { mostRecent in
            Text(mostRecent ? "Most Recent" : "Least Recent").tag(mostRecent)
          }
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
