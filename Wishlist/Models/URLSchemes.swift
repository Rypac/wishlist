import Combine
import Domain
import Foundation

final class URLSchemeHandler {
  struct Environment {
    var addApps: (_ ids: [AppID]) -> AnyPublisher<Bool, Never>
    var deleteAllApps: () throws -> Void
  }

  private var environment: Environment

  private var cancellables = Set<AnyCancellable>()

  init(environment: Environment) {
    self.environment = environment
  }

  deinit {
    for cancellable in cancellables {
      cancellable.cancel()
    }
  }

  func handle(_ urlScheme: URLScheme) throws {
    switch urlScheme {
    case .addApps(let ids):
      environment.addApps(ids)
        .sink { result in
          print("Successfully added apps: \(result)")
        }
        .store(in: &cancellables)
    case .deleteAll:
      try environment.deleteAllApps()
    case .export: break
    case .viewApp: break
    }
  }
}
