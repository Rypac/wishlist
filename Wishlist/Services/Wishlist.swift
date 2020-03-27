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

  func write(apps: [App]) {
    do {
      try database.write(apps: apps)
      appsUpdatedSubject.send()
    } catch {
      print("Failed to write app updates: \(error)")
    }
  }
}
