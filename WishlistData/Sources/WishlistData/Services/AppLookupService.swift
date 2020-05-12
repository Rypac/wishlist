import Combine

public protocol AppLookupService {
  func lookup(ids: [App.ID]) -> AnyPublisher<[App], Error>
}
