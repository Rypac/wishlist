import Combine
import Foundation
import SwiftUI
import Domain
import Services

@main
final class Wishlist: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup { [urlSchemeHandler = appDelegate.urlSchemeHandler] in
      ContentView(
        environment: ContentViewEnvironment(
          apps: appDelegate.appRepository.appPublisher.catch { _ in Just([]) }.eraseToAnyPublisher(),
          versionHistory: appDelegate.appRepository.versionsPublisher(id:),
          sortOrderState: appDelegate.settings.sortOrderStatePublisher
        )
      )
      .onOpenURL { url in
        if let urlScheme = URLScheme(rawValue: url) {
          urlSchemeHandler.handle(urlScheme)
        }
      }
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

  func versionsPublisher(id: AppID) -> AnyPublisher<[Version], Never> {
    Deferred {
      Optional.Publisher(try? versionHistory(id: id))
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
