import Foundation

struct App: Identifiable, Codable {
  let id: Int
  let title: String
  let seller: String
  let description: String
  let url: URL
  let iconURL: URL
  let price: Double
  let formattedPrice: String
  let bundleID: String
  let version: String
  let releaseDate: Date
  let updateDate: Date

  enum CodingKeys: String, CodingKey {
    case id = "trackId"
    case title = "trackName"
    case seller = "artistName"
    case description
    case url = "trackViewUrl"
    case iconURL = "artworkUrl100"
    case price
    case formattedPrice
    case bundleID = "bundleId"
    case version
    case releaseDate
    case updateDate = "currentVersionReleaseDate"
  }
}
