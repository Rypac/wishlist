import Combine
import Foundation
import WishlistFoundation

public final class AddToWishlistService {
  private let appRepository: AppRepository
  private let appLookupService: AppLookupService

  private var cancellables = Set<AnyCancellable>()

  public init(appRepository: AppRepository, appLookupService: AppLookupService) {
    self.appRepository = appRepository
    self.appLookupService = appLookupService
  }

  deinit {
    cancellables.forEach { cancellable in
      cancellable.cancel()
    }
  }

  public func addApps(urls: [URL]) -> AnyPublisher<[App], Error> {
    addApps(ids: AppStore.extractIDs(from: urls))
  }

  public func addApps(ids: [Int]) -> AnyPublisher<[App], Error> {
    appLookupService.lookup(ids: ids)
      .handleEvents(receiveOutput: { [appRepository] apps in
        do {
          if !apps.isEmpty {
            try appRepository.add(apps)
          }
        } catch {
          print("Failed to add apps")
        }
      })
      .eraseToAnyPublisher()
  }
}
