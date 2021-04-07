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
          repository: AllAppsRepository(
            apps: appDelegate.reactiveEnvironment.appsPublisher,
            app: appDelegate.reactiveEnvironment.appPublisher(forId:),
            versionHistory: appDelegate.reactiveEnvironment.versionsPublisher(forId:),
            recordViewed: appDelegate.reactiveEnvironment.recordAppViewed,
            deleteApps: appDelegate.reactiveEnvironment.deleteApps(ids:),
            deleteAllApps: appDelegate.reactiveEnvironment.deleteAllApps
          ),
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
  private enum RefreshStrategy {
    case all
    case only([AppID])
  }

  private let refreshTrigger = PassthroughSubject<RefreshStrategy, Never>()
  private var appRepository: AppRepository

  init(repository: AppRepository) {
    appRepository = repository
  }

  var appsPublisher: AnyPublisher<[AppDetails], Never> {
    refreshTrigger
      .prepend(.all)
      .tryMap { _ in try appRepository.fetchAll() }
      .catch { _ in Just([]) }
      .eraseToAnyPublisher()
  }

  func appPublisher(forId id: AppID) -> AnyPublisher<AppDetails?, Never> {
    refreshTrigger
      .prepend(.only([id]))
      .filter { strategy in
        switch strategy {
        case .all: return true
        case .only(let ids): return ids.contains(id)
        }
      }
      .tryMap { _ in try appRepository.fetch(id: id) }
      .catch { _ in Just(nil) }
      .eraseToAnyPublisher()
  }

  func versionsPublisher(forId id: AppID) -> AnyPublisher<[Version], Never> {
    refreshTrigger
      .prepend(.only([id]))
      .filter { strategy in
        switch strategy {
        case .all: return true
        case .only(let ids): return ids.contains(id)
        }
      }
      .compactMap { _ in try? appRepository.versionHistory(id: id) }
      .eraseToAnyPublisher()
  }

  func saveApps(_ apps: [AppDetails]) throws {
    try appRepository.add(apps)
    refresh(.only(apps.map(\.id)))
  }

  func deleteApps(ids: [AppID]) throws {
    try appRepository.delete(ids: ids)
    refresh(.only(ids))
  }

  func deleteAllApps() throws {
    try appRepository.deleteAll()
    refresh(.all)
  }

  func recordAppViewed(id: AppID, atDate date: Date) {
    do {
      try appRepository.viewedApp(id: id, at: date)
      refresh(.only([id]))
    } catch {
      print(error)
    }
  }

  func refresh() {
    refresh(.all)
  }

  private func refresh(_ strategy: RefreshStrategy) {
    refreshTrigger.send(strategy)
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
