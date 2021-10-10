import Foundation

public protocol AppPersistence {
  func fetchAll() async throws -> [AppDetails]
  func fetch(id: AppID) async throws -> AppDetails?
  func add(_ app: AppDetails) async throws
  func add(_ apps: [AppDetails]) async throws
  func delete(id: AppID) async throws
  func delete(ids: [AppID]) async throws
  func deleteAll() async throws
  func viewedApp(id: AppID, at date: Date) async throws
  func notifyApp(id: AppID, for notifications: Set<ChangeNotification>) async throws
  func versionHistory(id: AppID) async throws -> [Version]
}
