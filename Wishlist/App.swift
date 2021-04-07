import Combine
import Foundation
import SwiftUI
import Domain
import Services

@main
final class Wishlist: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup { [handleURLScheme = appDelegate.urlSchemeHandler.handle] in
      ContentView(
        environment: ContentViewEnvironment(
          apps: appDelegate.reactiveEnvironment.appsPublisher,
          deleteApps: appDelegate.appRepository.delete(ids:),
          deleteAllApps: appDelegate.reactiveEnvironment.deleteAllApps,
          versionHistory: appDelegate.reactiveEnvironment.versionsPublisher(id:),
          recordAppViewed: appDelegate.reactiveEnvironment.recordAppViewed,
          theme: appDelegate.settings.$theme,
          sortOrderState: appDelegate.settings.sortOrderStatePublisher,
          checkForUpdates: appDelegate.updateChecker.update,
          system: .live(())
        )
      )
      .onOpenURL { url in
        if let urlScheme = URLScheme(rawValue: url) {
          handleURLScheme(urlScheme)
        }
      }
    }
  }
}

struct ReactiveAppEnvironment {
  private let refreshTrigger = PassthroughSubject<Void, Never>()
  private var appRepository: AppRepository

  init(repository: AppRepository) {
    appRepository = repository
  }

  var appsPublisher: AnyPublisher<[AppDetails], Never> {
    refreshTrigger
      .prepend(())
      .tryMap(appRepository.fetchAll)
      .catch { _ in Just([]) }
      .eraseToAnyPublisher()
  }

  func versionsPublisher(id: AppID) -> AnyPublisher<[Version], Never> {
    Deferred {
      Optional.Publisher(try? appRepository.versionHistory(id: id))
    }
    .eraseToAnyPublisher()
  }

  func saveApps(_ apps: [AppDetails]) throws {
    try appRepository.add(apps)
    refresh()
  }

  func deleteAllApps() throws {
    try appRepository.deleteAll()
    refresh()
  }

  func recordAppViewed(id: AppID, atDate date: Date) {
    do {
      try appRepository.viewedApp(id: id, at: date)
      refresh()
    } catch {
      print(error)
    }
  }

  func refresh() {
    refreshTrigger.send(())
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
