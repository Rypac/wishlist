import Combine
import Domain
import Foundation
import SwiftUI
import ToolboxUI
import UniformTypeIdentifiers

struct AppListRepository {
  var apps: AnyPublisher<[AppDetails], Never>
  var app: (AppID) -> AnyPublisher<AppDetails?, Never>
  var versionHistory: (AppID) -> AnyPublisher<[Version], Never>
  var checkForUpdates: () async throws -> Void
  var recordViewed: (AppID, Date) async throws -> Void
  var addApps: ([URL]) async throws -> Void
  var deleteApps: ([AppID]) async throws -> Void
  var deleteAllApps: () async throws -> Void
}

extension AppListRepository {
  func repository(for id: AppID) -> AppDetailsRepository {
    AppDetailsRepository(
      app: app(id),
      versionHistory: versionHistory(id),
      delete: { try await deleteApps([id]) },
      recordViewed: { date in try await recordViewed(id, date) }
    )
  }
}

@MainActor
final class AppListViewModel: ObservableObject {
  struct Environment {
    var repository: AppListRepository
    var sortOrder: AnyPublisher<SortOrderState, Never>
    var system: SystemEnvironment
  }

  @Published private(set) var apps: [AppDetails] = []
  @Published var viewingAppDetails: AppDetails? = nil
  @Input var filterQuery: String = ""

  let environment: Environment

  init(environment: Environment) {
    self.environment = environment

    environment.repository.apps
      .combineLatest(
        environment.sortOrder.removeDuplicates(),
        $filterQuery.removeDuplicates()
      ) { apps, sortOrderState, query in
        apps.applying(sortOrderState, titleFilter: query)
      }
      .assign(to: &$apps)
  }

  func checkForUpdates() async {
    do {
      try await environment.repository.checkForUpdates()
    } catch {
      print("Failed to update apps: \(error)")
    }
  }

  func addApps(_ urls: [URL]) {
    Task {
      do {
        try await environment.repository.addApps(urls)
      } catch {
        print("Failed to add apps: \(urls)")
      }
    }
  }

  func deleteApp(_ id: AppID) {
    apps.removeAll(where: { $0.id == id })

    Task {
      do {
        try await environment.repository.deleteApps([id])
      } catch {
        print("Failed to delete app with id: \(id)")
      }
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
    List(viewModel.apps) { app in
      AppRow {
        HStack {
          AppIcon(app.icon.medium, width: 50)
          Text(app.title)
            .fontWeight(.medium)
          Spacer(minLength: 8)
          AppUpdateDetails(date: app.version.date, seen: true)
        }
      } onSelect: {
        viewModel.viewingAppDetails = app
      } onShare: {
        [app.url]
      } onDelete: {
        viewModel.deleteApp(app.id)
      }
      .onDrag {
        NSItemProvider(url: app.url, title: app.title)
      }
    }
    .onDrop(of: [.url], isTargeted: nil) { itemProviders in
      for itemProvider in itemProviders {
        _ = itemProvider.loadObject(ofClass: URL.self) { url, error in
          if let url {
            viewModel.addApps([url])
          }
        }
      }
      return true
    }
    .searchable(text: $viewModel.filterQuery)
    .refreshable {
      await viewModel.checkForUpdates()
    }
    .listStyle(.plain)
    .navigation(item: $viewModel.viewingAppDetails) { app in
      AppDetailsView(viewModel: viewModel.detailViewModel(app))
    }
  }
}

private struct AppRow<Content: View>: View {
  @ViewBuilder let content: () -> Content
  let onSelect: () -> Void
  let onShare: () -> [Any]
  let onDelete: () -> Void

  @State private var displayShareSheet: Bool = false

  var body: some View {
    Button {
      onSelect()
    } label: {
      HStack {
        content()
        Spacer()
        SFSymbol.chevronForward
          .font(.caption.bold())
          .foregroundColor(Color(.tertiaryLabel))
      }
    }
    .contextMenu {
      shareButton
      Divider()
      deleteButton
    }
    .swipeActions(edge: .leading, allowsFullSwipe: true) {
      shareButton
        .tint(.blue)
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
      deleteButton
    }
    .sheet(isPresented: $displayShareSheet) {
      ActivityView(activityItems: onShare(), applicationActivities: nil)
    }
  }

  private var shareButton: some View {
    Button {
      displayShareSheet = true
    } label: {
      Label("Share…", systemImage: SFSymbol.share.rawValue)
    }
  }

  private var deleteButton: some View {
    Button(role: .destructive) {
      withAnimation {
        onDelete()
      }
    } label: {
      Label("Delete", systemImage: SFSymbol.trash.rawValue)
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
        .foregroundColor(.secondary)
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
  func applying(_ sorting: SortOrderState, titleFilter: String) -> [AppDetails] {
      filter { app in
        guard titleFilter.isEmpty || app.title.localizedCaseInsensitiveContains(titleFilter) else {
          return false
        }
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
