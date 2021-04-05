import Combine
import Domain
import Foundation
import SwiftUI

final class AppListViewModel: ObservableObject {
  struct Environment {
    var apps: AnyPublisher<[AppDetails], Never>
    var sortOrder: AnyPublisher<SortOrderState, Never>
    var deleteApps: ([AppID]) throws -> Void
    var versionHistory: (AppDetails.ID) -> AnyPublisher<[Version], Never>
  }

  @Published private(set) var apps: [AppDetails] = []

  let environment: Environment

  init(environment: Environment) {
    self.environment = environment

    environment.apps
      .combineLatest(environment.sortOrder.removeDuplicates())
      .map { apps, sortOrderState in
        apps.applying(sortOrderState)
      }
      .assign(to: &$apps)
  }

  func deleteApps(_ ids: [AppID]) {
    do {
      try environment.deleteApps(ids)
      apps.removeAll(where: { ids.contains($0.id) })
    } catch {
      print("Failed to delete apps with ids: \(ids)")
    }
  }

  func detailViewModel(_ app: AppDetails) -> AppDetailsViewModel {
    AppDetailsViewModel(
      app: app,
      environment: AppDetailsViewModel.Environment(
        versionHistory: environment.versionHistory(app.id)
      )
    )
  }
}

struct NewAppListView: View {
  @StateObject var viewModel: AppListViewModel

  var body: some View {
    List {
      ForEach(viewModel.apps) { app in
        NavigationLink(destination: NewAppDetailsView(viewModel: viewModel.detailViewModel(app))) {
          AppRowContent(
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
