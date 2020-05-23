import Combine

public protocol AppLookupService {
  func lookup(ids: [App.ID]) -> AnyPublisher<[AppSnapshot], Error>
}
