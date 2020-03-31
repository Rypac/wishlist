import Foundation
import Combine

public final class Wishlist {
  public let apps: AnyPublisher<[App], Never>

  private let database: Database
  private let appLookupService: AppLookupService
  private let appsUpdatedSubject = PassthroughSubject<Void, Never>()

  private var cancellables = Set<AnyCancellable>()

  public init(database: Database, appLookupService: AppLookupService) {
    self.database = database
    self.appLookupService = appLookupService
    self.apps = appsUpdatedSubject
      .prepend(())
      .tryMap(database.read)
      .replaceError(with: [])
      .eraseToAnyPublisher()
  }

  deinit {
    cancellables.forEach { cancellable in
      cancellable.cancel()
    }
  }

  public func app(withId id: Int) -> App? {
    guard let apps = try? database.read() else {
      return nil
    }
    return apps.first { $0.id == id }
  }

  public func addApp(id: Int) {
    appLookupService.lookup(ids: [id])
      .receive(on: DispatchQueue.main)
      .sink(receiveCompletion: { _ in }) { [weak self, database] apps in
        do {
          let newAppIds = apps.map(\.id)
          var currentApps = try database.read()
          currentApps.removeAll { newAppIds.contains($0.id) }
          currentApps.append(contentsOf: apps)
          self?.write(apps: currentApps)
        } catch {
          print(error)
        }
      }
      .store(in: &cancellables)
  }

  public func write(apps: [App]) {
    do {
      try database.write(apps: apps)
      appsUpdatedSubject.send()
    } catch {
      print("Failed to write app updates: \(error)")
    }
  }
}
