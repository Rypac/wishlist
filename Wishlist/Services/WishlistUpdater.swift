import Foundation
import Combine
import WishlistShared

final class WishlistUpdater {
  let wishlist: Wishlist
  let appStore: AppStoreService

  private var cancellables = Set<AnyCancellable>()

  init(wishlist: Wishlist, appStore: AppStoreService) {
    self.wishlist = wishlist
    self.appStore = appStore
  }

  deinit {
    cancellables.forEach { cancellable in
      cancellable.cancel()
    }
  }

  func performUpdate() {
    wishlist.apps
      .first()
      .setFailureType(to: Error.self)
      .flatMap { [appStore] apps in
        appStore.lookup(ids: apps.map(\.id))
      }
      .receive(on: DispatchQueue.main)
      .sink(receiveCompletion: { _ in }) { [wishlist] apps in
        wishlist.write(apps: apps)
      }
      .store(in: &cancellables)
  }
}
