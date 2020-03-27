import Foundation
import Combine

class AppStoreService {
  private let session: URLSession
  private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  init(session: URLSession = .shared) {
    self.session = session
  }

  func lookup(ids: [Int]) -> AnyPublisher<[App], Error> {
    if ids.isEmpty {
      return Result.Publisher([]).eraseToAnyPublisher()
    }

    var urlComponents = URLComponents(string: "https://itunes.apple.com/lookup")!
    urlComponents.queryItems = [
      URLQueryItem(name: "id", value: ids.map(String.init).joined(separator: ",")),
      URLQueryItem(name: "country", value: "au"),
      URLQueryItem(name: "limit", value: String(ids.count))
    ]

    return session.dataTaskPublisher(for: urlComponents.url!)
      .map(\.data)
      .decode(type: AppStoreLookupResponse.self, decoder: decoder)
      .map(\.results)
      .eraseToAnyPublisher()
  }
}

private struct AppStoreLookupResponse: Decodable {
  let resultCount: Int
  let results: [App]
}
