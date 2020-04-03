import Foundation
import Combine

public final class WishlistUpdater {
  private let wishlist: Wishlist
  private let appLookupService: AppLookupService

  private var cancellables = Set<AnyCancellable>()

  public init(wishlist: Wishlist, appLookupService: AppLookupService) {
    self.wishlist = wishlist
    self.appLookupService = appLookupService
  }

  deinit {
    cancellables.forEach { cancellable in
      cancellable.cancel()
    }
  }

  public func performUpdate() {
    wishlist.apps
      .first()
      .setFailureType(to: Error.self)
      .flatMap { [appLookupService] apps in
        appLookupService.lookup(ids: apps.map(\.id))
          .map { updatedApps in
            updatedApps.reduce(into: [App]()) { result, updatedApp in
              guard let app = apps.first(where: { $0.id == updatedApp.id }) else {
                return
              }
              if updatedApp.updateDate > app.updateDate {
                result.append(updatedApp)
              }
            }
          }
      }
      .receive(on: DispatchQueue.main)
      .sink(receiveCompletion: { _ in }) { [wishlist] apps in
        if !apps.isEmpty {
          wishlist.update(apps: apps)
        }
      }
      .store(in: &cancellables)
  }
}
