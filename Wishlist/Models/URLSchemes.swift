import Combine
import Domain
import Foundation

final class URLSchemeHandler {
  struct Environment {
    var addApps: (_ ids: [AppID]) async throws -> Void
    var deleteAllApps: () async throws -> Void
  }

  private let environment: Environment

  private var cancellables = Set<Task<Void, Never>>()

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
      cancellables.insert(
        Task { [environment] in
          do {
            try await environment.addApps(ids)
            print("Successfully added apps")
          } catch {
            print("Failed to add apps")
          }
        }
      )
    case .deleteAll:
      Task { [environment] in
        try await environment.deleteAllApps()
      }
    case .export: break
    case .viewApp: break
    }
  }
}
