import Foundation
import Combine
import WishlistData

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

    // Randomise order of query items to decrease chance of stale API cache.
    urlComponents.queryItems = [
      URLQueryItem(name: "id", value: ids.shuffled().map(String.init).joined(separator: ",")),
      URLQueryItem(name: "country", value: "au"),
      URLQueryItem(name: "media", value: "software"),
      URLQueryItem(name: "limit", value: String(ids.count))
    ].shuffled()

    let request = URLRequest(url: urlComponents.url!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)

    return session.dataTaskPublisher(for: request)
      .tryMap { [decoder] data, _ in
//        print(data.prettyPrintedJSONString!)
        return try decoder.decode(LookupResponse.self, from: data).results.map(App.init)
      }
      .eraseToAnyPublisher()
  }
}

private struct LookupResponse: Decodable {
  let resultCount: Int
  let results: [App]

  struct App: Identifiable, Codable {
    let id: Int
    let title: String
    let seller: String
    let description: String
    let url: URL
    let iconSmallURL: URL
    let iconMediumURL: URL
    let iconLargeURL: URL
    let price: Double
    let formattedPrice: String
    let bundleID: String
    let version: String
    let releaseDate: Date
    let updateDate: Date
    let releaseNotes: String?

    enum CodingKeys: String, CodingKey {
      case id = "trackId"
      case title = "trackName"
      case seller = "artistName"
      case description
      case url = "trackViewUrl"
      case iconSmallURL = "artworkUrl60"
      case iconMediumURL = "artworkUrl100"
      case iconLargeURL = "artworkUrl512"
      case price
      case formattedPrice
      case bundleID = "bundleId"
      case version
      case releaseDate
      case updateDate = "currentVersionReleaseDate"
      case releaseNotes
    }
  }
}

private extension App {
  init(app: LookupResponse.App) {
    self.init(
      id: app.id,
      title: app.title,
      seller: app.seller,
      description: app.description,
      url: app.url,
      icon: App.Icon(small: app.iconSmallURL, medium: app.iconMediumURL, large: app.iconLargeURL),
      price: app.price,
      formattedPrice: app.formattedPrice,
      bundleID: app.bundleID,
      version: app.version,
      releaseDate: app.releaseDate,
      updateDate: app.updateDate,
      releaseNotes: app.releaseNotes
    )
  }
}

extension Data {
    var prettyPrintedJSONString: NSString? { /// NSString gives us a nice sanitized debugDescription
        guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let prettyPrintedString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return nil }

        return prettyPrintedString
    }
}
