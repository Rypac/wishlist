import Combine

public protocol Database {
  func publisher() -> AnyPublisher<[App], Never>
  func fetchAll() throws -> [App]
  func fetch(id: Int) throws -> App?
  func add(app: App) throws
  func add(apps: [App]) throws
  func remove(app: App) throws
  func remove(apps: [App]) throws
}
