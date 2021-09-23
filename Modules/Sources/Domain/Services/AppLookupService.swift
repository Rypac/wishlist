import Combine

public protocol AppLookupService {
  func lookup(ids: [AppID]) async throws -> [AppSummary]
}
