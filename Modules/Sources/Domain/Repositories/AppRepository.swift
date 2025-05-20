import Combine
import Foundation
import Toolbox

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

  public func fetchApps() async throws -> [AppDetails] {
    try await persistence.fetchAll()
  }

  public var appsPublisher: some Publisher<[AppDetails], Never> {
    refreshTrigger
      .prepend(.all)
      .asyncTryMap { [persistence] _ in try await persistence.fetchAll() }
      .catch { _ in Just([]) }
      .receive(on: DispatchQueue.main)
  }

  public func appPublisher(forId id: AppID) -> some Publisher<AppDetails?, Never> {
    refreshTrigger
      .prepend(.only([id]))
      .filter { $0.includes(id: id) }
      .asyncTryMap { [persistence] _ in try await persistence.fetch(id: id) }
      .catch { _ in Just(nil) }
      .receive(on: DispatchQueue.main)
  }

  public func versionsPublisher(forId id: AppID) -> some Publisher<[Version], Never> {
    Deferred { [persistence] in
      Future { promise in
        Task {
          do {
            promise(.success(try await persistence.versionHistory(id: id)))
          } catch {
            promise(.success([]))
          }
        }
      }
    }
    .receive(on: DispatchQueue.main)
  }

  public func saveApps(_ apps: [AppDetails]) async throws {
    try await persistence.add(apps)
    refreshTrigger.send(.only(apps.map(\.id)))
  }

  public func deleteApps(ids: [AppID]) async throws {
    try await persistence.delete(ids: ids)
    refreshTrigger.send(.only(ids))
  }

  public func deleteAllApps() async throws {
    try await persistence.deleteAll()
    refreshTrigger.send(.all)
  }

  public func recordAppViewed(id: AppID, atDate date: Date) async throws {
    try await persistence.viewedApp(id: id, at: date)
    refreshTrigger.send(.only([id]))
  }

  public func refresh() {
    refreshTrigger.send(.all)
  }
}

extension AppRepository.RefreshStrategy {
  fileprivate func includes(id: AppID) -> Bool {
    switch self {
    case .all: true
    case .only(let ids): ids.contains(id)
    }
  }
}
