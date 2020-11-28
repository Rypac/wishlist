import Foundation
import Combine
import Domain

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

  public func lookup(ids: [App.ID]) -> AnyPublisher<[AppSnapshot], Error> {
    if ids.isEmpty {
      return Result.Publisher([]).eraseToAnyPublisher()
    }

    var urlComponents = URLComponents(string: "https://itunes.apple.com/lookup")!

    // Randomise order of query items to decrease chance of stale API cache.
    urlComponents.queryItems = [
      URLQueryItem(name: "id", value: ids.shuffled().map { String($0.rawValue) }.joined(separator: ",")),
      URLQueryItem(name: "country", value: "au"),
      URLQueryItem(name: "media", value: "software"),
      URLQueryItem(name: "limit", value: String(ids.count))
    ].shuffled()

    let request = URLRequest(url: urlComponents.url!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)

    return session.dataTaskPublisher(for: request)
      .tryMap { [decoder] data, _ in
        try decoder.decode(LookupResponse.self, from: data).results.map(AppSnapshot.init)
      }
      .eraseToAnyPublisher()
  }
}

private struct LookupResponse: Decodable {
  let resultCount: Int
  let results: [App]

  struct App: Identifiable, Codable {
    let id: AppID
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

private extension AppSnapshot {
  init(app: LookupResponse.App) {
    self.init(
      id: app.id,
      title: app.title.trimmingCharacters(in: .whitespacesAndNewlines),
      seller: app.seller.trimmingCharacters(in: .whitespacesAndNewlines),
      description: app.description.trimmingCharacters(in: .whitespacesAndNewlines),
      url: app.url,
      icon: Icon(small: app.iconSmallURL, medium: app.iconMediumURL, large: app.iconLargeURL),
      price: Price(value: app.price, formatted: app.formattedPrice),
      bundleID: app.bundleID,
      version: app.version,
      releaseDate: app.releaseDate,
      updateDate: app.updateDate,
      releaseNotes: app.releaseNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
    )
  }
}
