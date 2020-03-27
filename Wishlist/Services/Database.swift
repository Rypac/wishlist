import Foundation

class Database {
  private let databaseLocation: URL

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
    databaseLocation = documentsDirectory.appendingPathComponent("apps.json", isDirectory: false)
  }

  private func populate() throws {
    let url = Bundle.main.url(forResource: "apps", withExtension: "json")!
    let data = try Data(contentsOf: url)
    let apps = try decoder.decode([App].self, from: data)
    try write(apps: apps)
  }

  func read() throws -> [App] {
    let data = try Data(contentsOf: databaseLocation)
    return try decoder.decode([App].self, from: data)
  }

  func write(apps: [App]) throws {
    let data = try encoder.encode(apps)
    try data.write(to: databaseLocation)
  }
}
