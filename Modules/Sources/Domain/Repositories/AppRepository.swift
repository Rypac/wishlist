import Foundation

public protocol AppRepository {
  func fetchAll() throws -> [AppDetails]
  func fetch(id: AppID) throws -> AppDetails?
  func add(_ app: AppDetails) throws
  func add(_ apps: [AppDetails]) throws
  func delete(id: AppID) throws
  func delete(ids: [AppID]) throws
  func deleteAll() throws
  func viewedApp(id: AppID, at date: Date) throws
  func notifyApp(id: AppID, for notifications: Set<ChangeNotification>) throws
  func versionHistory(id: AppID) throws -> [Version]
}
