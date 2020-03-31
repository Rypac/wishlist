import Foundation
import WishlistShared

public final class FileDatabase: Database {
  private let databaseURL: URL

  private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()
  private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  public init(fileManager: FileManager = .default) throws {
    guard let documentsDirectory = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.wishlist.database") else {
      throw WishlistDatabaseError()
    }

    databaseURL = documentsDirectory.appendingPathComponent("apps.json", isDirectory: false)

    if !fileManager.fileExists(atPath: databaseURL.path) {
      try write(apps: [])
    }
  }

  public func read() throws -> [App] {
    let data = try Data(contentsOf: databaseURL)
    return try decoder.decode([App].self, from: data)
  }

  public func write(apps: [App]) throws {
    let data = try encoder.encode(apps)
    try data.write(to: databaseURL)
  }
}

private struct WishlistDatabaseError: Error {}
