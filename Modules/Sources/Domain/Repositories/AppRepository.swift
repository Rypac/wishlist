import Combine
import Foundation

public protocol AppRepository {
  func publisher() -> AnyPublisher<[AppDetails], Never>
  func updates() -> AnyPublisher<[AppDetails], Never>
  func fetchAll() throws -> [AppDetails]
  func fetch(id: AppID) throws -> AppDetails?
  func add(_ app: AppSummary) throws
  func add(_ apps: [AppSummary]) throws
  func delete(id: AppID) throws
  func delete(ids: [AppID]) throws
  func deleteAll() throws
  func viewedApp(id: AppID, at date: Date) throws
  func notify(id: AppID, for notifications: Set<ChangeNotification>) throws
  func versionHistory(id: AppID) throws -> [Version]
}

public extension AppRepository {
  func fetch(id: AppID) throws -> AppDetails? {
    try fetchAll().first { $0.id == id }
  }

  func add(_ app: AppSummary) throws {
    try add([app])
  }

  func delete(id: AppID) throws {
    try delete(ids: [id])
  }

  func delete(_ app: AppDetails) throws {
    try delete(id: app.id)
  }

  func delete(_ apps: [AppDetails]) throws {
    try delete(ids: apps.map(\.id))
  }
}
