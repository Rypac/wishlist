import Foundation

struct App: Identifiable, Codable {
  let id: Int
  let title: String
  let author: String
  let description: String
  let url: URL
  let iconURL: URL
  let price: Double
  let formattedPrice: String
  let version: String
  let genres: [String]
}
