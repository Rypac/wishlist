import Combine
import Foundation

public final class AppRepository {
  enum RefreshStrategy {
    case all
    case only([AppID])
  }

  private let refreshTrigger = PassthroughSubject<RefreshStrategy, Never>()
  private let persistence: AppPersistence

  public init(persistence: AppPersistence) {
    self.persistence = persistence
  }

  public func fetchApps() throws -> [AppDetails] {
    try persistence.fetchAll()
  }

  public var appsPublisher: AnyPublisher<[AppDetails], Never> {
    refreshTrigger
      .prepend(.all)
      .tryMap { [persistence] _ in try persistence.fetchAll() }
      .catch { _ in Just([]) }
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }

  public func appPublisher(forId id: AppID) -> AnyPublisher<AppDetails?, Never> {
    refreshTrigger
      .prepend(.only([id]))
      .filter { $0.includes(id: id) }
      .tryMap { [persistence] _ in try persistence.fetch(id: id) }
      .catch { _ in Just(nil) }
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }

  public func versionsPublisher(forId id: AppID) -> AnyPublisher<[Version], Never> {
    Deferred { [persistence] in
      Optional.Publisher(try? persistence.versionHistory(id: id))
    }
    .eraseToAnyPublisher()
  }

  public func saveApps(_ apps: [AppDetails]) throws {
    try persistence.add(apps)
    refreshTrigger.send(.only(apps.map(\.id)))
  }

  public func deleteApps(ids: [AppID]) throws {
    try persistence.delete(ids: ids)
    refreshTrigger.send(.only(ids))
  }

  public func deleteAllApps() throws {
    try persistence.deleteAll()
    refreshTrigger.send(.all)
  }

  public func recordAppViewed(id: AppID, atDate date: Date) throws {
    try persistence.viewedApp(id: id, at: date)
    refreshTrigger.send(.only([id]))
  }

  public func refresh() {
    refreshTrigger.send(.all)
  }
}

private extension AppRepository.RefreshStrategy {
  func includes(id: AppID) -> Bool {
    switch self {
    case .all: return true
    case .only(let ids): return ids.contains(id)
    }
  }
}
