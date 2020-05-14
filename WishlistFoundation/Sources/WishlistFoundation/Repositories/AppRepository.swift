import Combine

public protocol AppRepository {
  func publisher() -> AnyPublisher<[App], Never>
  func fetchAll() throws -> [App]
  func fetch(id: App.ID) throws -> App?
  func add(_ app: App) throws
  func add(_ apps: [App]) throws
  func update(_ app: App) throws
  func update(_ apps: [App]) throws
  func delete(id: App.ID) throws
  func delete(ids: [App.ID]) throws
}

public extension AppRepository {
  func fetch(id: App.ID) throws -> App? {
    try fetchAll().first { $0.id == id }
  }

  func add(_ app: App) throws {
    try add([app])
  }

  func update(_ app: App) throws {
    try update([app])
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
