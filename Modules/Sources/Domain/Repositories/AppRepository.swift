import Combine
import Foundation

public final class AppRepository {
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

  private var persistence: AppPersistence
  private var cancellable: Cancellable?

  public init(persistence: AppPersistence) {
    self.persistence = persistence
    self.cancellable = actionTrigger
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

  public var appsPublisher: AnyPublisher<[AppDetails], Never> {
    apps
      .map { Array($0.values) }
      .eraseToAnyPublisher()
  }

  public func appPublisher(forId id: AppID) -> AnyPublisher<AppDetails?, Never> {
    apps
      .map { $0[id] }
      .removeDuplicates()
      .eraseToAnyPublisher()
  }

  public func versionsPublisher(forId id: AppID) -> AnyPublisher<[Version], Never> {
    appPublisher(forId: id)
      .compactMap { [versionHistory = persistence.versionHistory] app in
        guard let id = app?.id else {
          return nil
        }
        return try? versionHistory(id)
      }
      .eraseToAnyPublisher()
  }

  public func saveApps(_ apps: [AppDetails]) throws {
    try persistence.add(apps)
    actionTrigger.send(.update(apps))
  }

  public func deleteApps(ids: [AppID]) throws {
    try persistence.delete(ids: ids)
    actionTrigger.send(.delete(ids))
  }

  public func deleteAllApps() throws {
    try persistence.deleteAll()
    actionTrigger.send(.deleteAll)
  }

  public func recordAppViewed(id: AppID, atDate date: Date) {
    do {
      try persistence.viewedApp(id: id, at: date)
      actionTrigger.send(.viewed(id, date))
    } catch {
      print(error)
    }
  }

  public func refresh() throws {
    actionTrigger.send(.refresh(try persistence.fetchAll()))
  }
}
