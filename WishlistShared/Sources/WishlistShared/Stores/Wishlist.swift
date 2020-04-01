import Foundation
import Combine

public final class Wishlist {
  public let apps: AnyPublisher<[App], Never>

  private let database: Database
  private let appLookupService: AppLookupService

  private var cancellables = Set<AnyCancellable>()

  public init(database: Database, appLookupService: AppLookupService) {
    self.database = database
    self.appLookupService = appLookupService
    self.apps = database.publisher()
  }

  deinit {
    cancellables.forEach { cancellable in
      cancellable.cancel()
    }
  }

  public func app(withId id: Int) -> App? {
    do {
      return try database.fetch(id: id)
    } catch {
      return nil
    }
  }

  public func addApp(id: Int) {
    appLookupService.lookup(ids: [id])
      .receive(on: DispatchQueue.main)
      .sink(receiveCompletion: { _ in }) { [database] apps in
        do {
          guard let app = apps.first else {
            return
          }
          try database.add(app: app)
        } catch {
          print(error)
        }
      }
      .store(in: &cancellables)
  }

  public func update(apps: [App]) {
    do {
      try database.add(apps: apps)
    } catch {
      print("Failed to update apps: \(error)")
    }
  }

  public func remove(app: App) {
    do {
      try database.remove(app: app)
    } catch {
      print("Failed to remove app: \(error)")
    }
  }

  public func remove(apps: [App]) {
    do {
      try database.remove(apps: apps)
    } catch {
      print("Failed to remove app: \(error)")
    }
  }

  public func removeAll() {
    do {
      let apps = try database.fetchAll()
      try database.remove(apps: apps)
    } catch {
      print("Failed to remove all apps: \(error)")
    }
  }
}
