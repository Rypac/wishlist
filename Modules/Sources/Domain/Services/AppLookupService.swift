import Combine

public protocol AppLookupService {
  func lookup(ids: [AppID]) -> AnyPublisher<[AppSummary], Error>
}
