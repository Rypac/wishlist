import Foundation

public struct App: Identifiable, Codable {
  public let id: Int
  public let title: String
  public let seller: String
  public let description: String
  public let url: URL
  public let iconURL: URL
  public let price: Double
  public let formattedPrice: String
  public let bundleID: String
  public let version: String
  public let releaseDate: Date
  public let updateDate: Date
  public let releaseNotes: String?

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
    case releaseNotes
  }
}
