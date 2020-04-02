import Foundation
import Combine
import WishlistShared

public final class AppStoreService: AppLookupService {
  private let session: URLSession
  private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  public init(session: URLSession = .shared) {
    self.session = session
  }

  public func lookup(ids: [Int]) -> AnyPublisher<[App], Error> {
    if ids.isEmpty {
      return Result.Publisher([]).eraseToAnyPublisher()
    }

    var urlComponents = URLComponents(string: "https://itunes.apple.com/lookup")!
    urlComponents.queryItems = [
      URLQueryItem(name: "id", value: ids.map(String.init).joined(separator: ",")),
      URLQueryItem(name: "entity", value: "software"),
      URLQueryItem(name: "country", value: "au"),
      URLQueryItem(name: "limit", value: String(ids.count))
    ]

    return session.dataTaskPublisher(for: urlComponents.url!)
      .tryMap { [decoder] data, _ in
        try decoder.decode(LookupResponse.self, from: data).results
      }
      .eraseToAnyPublisher()
  }
}

private struct LookupResponse: Decodable {
  let resultCount: Int
  let results: [App]
}
