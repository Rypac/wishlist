import Combine
import Domain
import Foundation
import SwiftUI
import ToolboxUI

struct AppListRepository {
  var apps: AnyPublisher<[AppDetails], Never>
  var app: (AppID) -> AnyPublisher<AppDetails?, Never>
  var versionHistory: (AppID) -> AnyPublisher<[Version], Never>
  var recordViewed: (AppID, Date) throws -> Void
  var deleteApps: ([AppID]) throws -> Void
  var deleteAllApps: () throws -> Void
}

extension AppListRepository {
  func repository(for id: AppID) -> AppDetailsRepository {
    AppDetailsRepository(
      app: app(id),
      versionHistory: versionHistory(id),
      delete: { try deleteApps([id]) },
      recordViewed: { date in try recordViewed(id, date) }
    )
  }
}

final class AppListViewModel: ObservableObject {
  struct Environment {
    var repository: AppListRepository
    var sortOrder: AnyPublisher<SortOrderState, Never>
    var system: SystemEnvironment
  }

  @Published private(set) var apps: [AppDetails] = []

  let environment: Environment

  init(environment: Environment) {
    self.environment = environment

    environment.repository.apps
      .combineLatest(environment.sortOrder.removeDuplicates())
      .map { apps, sortOrderState in
        apps.applying(sortOrderState)
      }
      .assign(to: &$apps)
  }

  func deleteApps(_ ids: [AppID]) {
    do {
      try environment.repository.deleteApps(ids)
      apps.removeAll(where: { ids.contains($0.id) })
    } catch {
      print("Failed to delete apps with ids: \(ids)")
    }
  }

  func detailViewModel(_ app: AppDetails) -> AppDetailsViewModel {
    AppDetailsViewModel(
      app: app,
      environment: AppDetailsViewModel.Environment(
        repository: environment.repository.repository(for: app.id),
        system: environment.system
      )
    )
  }
}

struct AppListView: View {
  @StateObject var viewModel: AppListViewModel

  var body: some View {
    List {
      ForEach(viewModel.apps) { app in
        NavigationLink(destination: AppDetailsView(viewModel: viewModel.detailViewModel(app))) {
          AppRow(
            title: app.title,
            details: .updated(app.version.date, seen: true),
            icon: app.icon.medium
          )
        }
      }
      .onDelete { indexes in
        let ids = viewModel.apps.enumerated().compactMap { index, app in
          indexes.contains(index) ? app.id : nil
        }
        viewModel.deleteApps(ids)
      }
    }
    .listStyle(PlainListStyle())
  }
}

private struct AppRow: View {
  let title: String
  let details: AppListSummary.Details
  let icon: URL

  var body: some View {
    HStack {
      AppIcon(icon, width: 50)
      Text(title)
        .fontWeight(.medium)
      Spacer(minLength: 8)

      switch details {
      case let .price(price, change):
        AppPriceDetails(price: price, change: change)
      case let .updated(date, seen):
        AppUpdateDetails(date: date, seen: seen)
      }
    }
  }
}

private struct AppPriceDetails: View {
  let price: String
  let change: AppListSummary.PriceChange

  var body: some View {
    HStack {
      if change == .increase {
        SFSymbol.arrowUp
      } else if change == .decrease {
        SFSymbol.arrowDown
      }
      Text(price)
        .lineLimit(1)
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
        .font(.callout)
        .lineLimit(1)

      if !seen {
        Circle()
          .foregroundColor(.blue)
          .frame(width: 15, height: 15)
          .offset(x: 8, y: -14)
      }
    }
  }
}

struct AppListSummary: Identifiable, Equatable {
  enum PriceChange {
    case same
    case decrease
    case increase
  }

  enum Details: Equatable {
    case price(String, change: PriceChange)
    case updated(Date, seen: Bool)
  }

  let id: AppID
  let selected: Bool
  let title: String
  let details: Details
  let icon: URL
  let url: URL
}

private extension NSItemProvider {
  convenience init(url: URL, title: String) {
    self.init(object: URLItemProvider(url: url, title: title))
    self.suggestedName = title
  }
}

private extension AppListSummary.Details {
  init(sortOrder: SortOrder, app: AppDetails) {
    switch sortOrder {
    case .updated:
      if let lastViewed = app.lastViewed {
        self = .updated(app.version.date, seen: lastViewed > app.version.date)
      } else {
        self = .updated(app.version.date, seen: app.firstAdded > app.version.date)
      }

    case .price, .title:
      self = .price(app.price.current.formatted, change: app.priceChange)
    }
  }
}

private extension AppDetails {
  var priceChange: AppListSummary.PriceChange {
    guard let previousPrice = price.previous else {
      return .same
    }

    if price.current == previousPrice {
      return .same
    }
    return price.current > previousPrice ? .increase : .decrease
  }
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
