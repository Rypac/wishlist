import Combine

public protocol AppLookupService {
  func lookup(ids: [Int]) -> AnyPublisher<[App], Error>
}
