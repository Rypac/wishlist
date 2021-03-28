import Combine
import Foundation
import SwiftUI
import Domain
import Services

@main
final class Wishlist: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      ContentView(
        environment: ContentViewEnvironment(
          apps: appDelegate.appRepository.appPublisher.catch { _ in Just([]) }.eraseToAnyPublisher(),
          sortOrderState: appDelegate.settings.sortOrderStatePublisher
        )
      )
    }
  }
}

private extension AppRepository {
  var appPublisher: AnyPublisher<[AppDetails], Error> {
    Deferred {
      Result.Publisher {
        try fetchAll()
      }
    }
    .eraseToAnyPublisher()
  }
}

private extension Settings {
  var sortOrderStatePublisher: AnyPublisher<SortOrderState, Never> {
    $sortOrder.publisher()
      .map { sortOrder in
        SortOrderState(
          sortOrder: sortOrder,
          configuration: SortOrder.Configuration(
            price: .init(sortLowToHigh: true, includeFree: true),
            title: .init(sortAToZ: true),
            update: .init(sortByMostRecent: true)
          )
        )
      }
      .eraseToAnyPublisher()
  }
}
