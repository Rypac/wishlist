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

final class ReactiveAppEnvironment {
  private enum Action {
    case refresh([AppDetails])
    case update([AppDetails])
    case delete([AppID])
    case viewed(AppID, Date)
    case deleteAll
  }

  private let refreshTrigger = PassthroughSubject<Void, Never>()
  private let actionTrigger = PassthroughSubject<Action, Never>()
  private let apps = CurrentValueSubject<[AppID: AppDetails], Never>([:])

  private var appRepository: AppRepository
  private var cancellable: Cancellable?

  init(repository: AppRepository) {
    appRepository = repository
    cancellable = actionTrigger
      .scan(into: [:]) { apps, update in
        switch update {
        case .refresh(let refreshedApps):
          apps.removeAll(keepingCapacity: true)
          if refreshedApps.count > apps.capacity {
            apps.reserveCapacity(refreshedApps.count)
          }
          for app in refreshedApps {
            apps[app.id] = app
          }
        case .update(let updatedApps):
          for app in updatedApps {
            apps[app.id] = app
          }
        case .delete(let ids):
          for id in ids {
            apps[id] = nil
          }
        case .viewed(let id, let date):
          apps[id]?.lastViewed = date
        case .deleteAll:
          apps.removeAll()
        }
      }
      .subscribe(apps)
  }

  var appsPublisher: AnyPublisher<[AppDetails], Never> {
    apps
      .map { Array($0.values) }
      .eraseToAnyPublisher()
  }

  func appPublisher(forId id: AppID) -> AnyPublisher<AppDetails?, Never> {
    apps
      .map { $0[id] }
      .removeDuplicates()
      .eraseToAnyPublisher()
  }

  func versionsPublisher(forId id: AppID) -> AnyPublisher<[Version], Never> {
    appPublisher(forId: id)
      .compactMap { [versionHistory = appRepository.versionHistory] app in
        guard let id = app?.id else {
          return nil
        }
        return try? versionHistory(id)
      }
      .eraseToAnyPublisher()
  }

  func saveApps(_ apps: [AppDetails]) throws {
    try appRepository.add(apps)
    actionTrigger.send(.update(apps))
  }

  func deleteApps(ids: [AppID]) throws {
    try appRepository.delete(ids: ids)
    actionTrigger.send(.delete(ids))
  }

  func deleteAllApps() throws {
    try appRepository.deleteAll()
    actionTrigger.send(.deleteAll)
  }

  func recordAppViewed(id: AppID, atDate date: Date) {
    do {
      try appRepository.viewedApp(id: id, at: date)
      actionTrigger.send(.viewed(id, date))
    } catch {
      print(error)
    }
  }

  func refresh() throws {
    actionTrigger.send(.refresh(try appRepository.fetchAll()))
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
