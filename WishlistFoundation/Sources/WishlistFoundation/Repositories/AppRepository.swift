import Combine
import Foundation

public protocol AppRepository {
  func publisher() -> AnyPublisher<[App], Never>
  func fetchAll() throws -> [App]
  func fetch(id: App.ID) throws -> App?
  func add(_ app: AppSnapshot) throws
  func add(_ apps: [AppSnapshot]) throws
  func delete(id: App.ID) throws
  func delete(ids: [App.ID]) throws
  func viewedApp(id: App.ID, at date: Date) throws
  func versionHistory(id: App.ID) throws -> [Version]
}

public extension AppRepository {
  func fetch(id: App.ID) throws -> App? {
    try fetchAll().first { $0.id == id }
  }

  func add(_ app: AppSnapshot) throws {
    try add([app])
  }

  func delete(id: App.ID) throws {
    try delete(ids: [id])
  }

  func delete(_ app: App) throws {
    try delete(id: app.id)
  }

  func delete(_ apps: [App]) throws {
    try delete(ids: apps.map(\.id))
  }
}
