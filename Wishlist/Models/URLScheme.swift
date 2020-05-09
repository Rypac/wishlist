import Foundation
import WishlistData

enum URLScheme {
  case addApps(ids: [App.ID])
  case viewApp(id: App.ID)
  case export
  case deleteAll
}

// MARK: - RawRepresentable

extension URLScheme: RawRepresentable {
  var rawValue: URL {
    var urlComponents = URLComponents()
    urlComponents.scheme = "appdates"
    switch self {
    case .addApps(let ids):
      urlComponents.host = "add"
      urlComponents.queryItems = [
        URLQueryItem(name: "id", value: ids.map(String.init).joined(separator: ","))
      ]
    case .viewApp(let id):
      urlComponents.host = "view"
      urlComponents.queryItems = [
        URLQueryItem(name: "id", value: String(id))
      ]
    case .export:
      urlComponents.host = "export"
    case .deleteAll:
      urlComponents.host = "deleteAll"
    }
    return urlComponents.url!
  }

  init?(rawValue url: URL) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
      return nil
    }

    switch components.host {
    case "add":
      guard let appIDs = components.queryItems?.first(where: { $0.name == "id" })?.value else {
        return nil
      }
      let ids = appIDs.split(separator: ",").compactMap { Int($0, radix: 10) }
      guard !ids.isEmpty else {
        return nil
      }
      self = .addApps(ids: ids)
    case "view":
      guard let appID = components.queryItems?.first(where: { $0.name == "id" })?.value, let id = Int(appID, radix: 10) else {
        return nil
      }
      self = .viewApp(id: id)
    case "export":
      self = .export
    case "deleteAll":
      self = .deleteAll
    default:
      return nil
    }
  }
}

// MARK: - Codable

extension URLScheme: Codable {
  private struct MalformedURLSchemeError: Error {}

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let url = try container.decode(URL.self)
    guard let urlScheme = URLScheme(rawValue: url) else {
      throw MalformedURLSchemeError()
    }
    self = urlScheme
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}