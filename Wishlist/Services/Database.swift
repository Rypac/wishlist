import Foundation

class Database {
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

  init(fileManager: FileManager = .default) throws {
    let documentsDirectory = try fileManager.url(
      for: .documentDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    databaseURL = documentsDirectory.appendingPathComponent("apps.json", isDirectory: false)

    if !fileManager.fileExists(atPath: databaseURL.path) {
      try populateWithDefaults()
    }
  }

  private func populateWithDefaults() throws {
    let url = Bundle.main.url(forResource: "apps", withExtension: "json")!
    let data = try Data(contentsOf: url)
    let apps = try decoder.decode([App].self, from: data)
    try write(apps: apps)
  }

  func read() throws -> [App] {
    let data = try Data(contentsOf: databaseURL)
    return try decoder.decode([App].self, from: data)
  }

  func write(apps: [App]) throws {
    let data = try encoder.encode(apps)
    try data.write(to: databaseURL)
  }
}
