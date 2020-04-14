import Combine
import Foundation

public final class AddToWishlistTask {
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

  public func addApps(ids: [Int]) {
    appLookupService.lookup(ids: ids)
      .receive(on: DispatchQueue.main)
      .sink(receiveCompletion: { _ in }) { [appRepository] apps in
        do {
          if !apps.isEmpty {
            try appRepository.add(apps)
          }
        } catch {
          print("Failed to add apps")
        }
      }
      .store(in: &cancellables)
  }
}
