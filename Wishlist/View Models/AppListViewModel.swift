import Combine
import SwiftUI

final class AppListViewModel: ObservableObject {
  @Published private(set) var apps: [App]

  private let settings: ObservableSettings
  private var cancellables = Set<AnyCancellable>()

  init(apps: [App], settings: ObservableSettings) {
    self.settings = settings
    self.apps = apps.sorted(by: settings.sortOrder)

    settings.sortOrderPublisher
      .prepend(settings.sortOrder) // Emit initial sort order again to work around layout issue.
      .removeDuplicates()
      .map(apps.sorted(by:))
      .receive(on: DispatchQueue.main)
      .sink { [unowned self] sortedApps in
        self.apps = sortedApps
      }
      .store(in: &cancellables)
  }

  deinit {
    cancellables.forEach { cancellable in
      cancellable.cancel()
    }
  }
}

extension AppListViewModel {
  func detailsViewModel(app: App) -> AppDetailsViewModel {
    AppDetailsViewModel(app: app)
  }

  var settingsViewModel: SettingsViewModel {
    SettingsViewModel(settings: settings)
  }

  func removeApps(at offsets: IndexSet) {
    apps.remove(atOffsets: offsets)
  }

  func moveApps(from fromOffsets: IndexSet, to toOffsets: Int) {
    apps.move(fromOffsets: fromOffsets, toOffset: toOffsets)
  }
}

private extension Array where Element == App {
  func sorted(by order: SortOrder) -> [App] {
    sorted(by: {
      switch order {
      case .title: return $0.title < $1.title
      case .price: return $0.price < $1.price
      }
    })
  }
}
