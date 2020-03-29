import Foundation
import Combine

final class Wishlist {
  let apps: AnyPublisher<[App], Never>

  private let database: Database
  private let appsUpdatedSubject = PassthroughSubject<Void, Never>()

  init(database: Database) {
    self.database = database
    self.apps = appsUpdatedSubject
      .prepend(())
      .tryMap(database.read)
      .replaceError(with: [])
      .eraseToAnyPublisher()
  }

  func app(withId id: Int) -> App? {
    guard let apps = try? database.read() else {
      return nil
    }
    return apps.first { $0.id == id }
  }

  func write(apps: [App]) {
    do {
      try database.write(apps: apps)
      appsUpdatedSubject.send()
    } catch {
      print("Failed to write app updates: \(error)")
    }
  }
}
