import Combine
import Foundation
import WishlistShared

public final class FileDatabase: Database {
  private let databaseURL: URL
  private let subject = PassthroughSubject<[App], Never>()

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

  public func publisher() -> AnyPublisher<[App], Never> {
    subject.eraseToAnyPublisher()
  }

  public func fetchAll() throws -> [App] {
    let data = try Data(contentsOf: databaseURL)
    return try decoder.decode([App].self, from: data)
  }

  public func fetch(id: Int) throws -> App? {
    let apps = try fetchAll()
    return apps.first { $0.id == id }
  }

  public func add(app: App) throws {
    var currentApps = try fetchAll()
    currentApps.removeAll { $0.id == app.id }
    currentApps.append(app)
    try write(apps: currentApps)
  }

  public func add(apps: [App]) throws {
    var currentApps = try fetchAll()
    currentApps.removeAll { currentApp in
      apps.contains { $0.id == currentApp.id }
    }
    currentApps.append(contentsOf: apps)
    try write(apps: currentApps)
  }

  public func remove(app: App) throws {
    var currentApps = try fetchAll()
    currentApps.removeAll { $0.id == app.id }
    try write(apps: currentApps)
  }

  public func remove(apps: [App]) throws {
    var currentApps = try fetchAll()
    currentApps.removeAll { currentApp in
      apps.contains { $0.id == currentApp.id }
    }
    try write(apps: currentApps)
  }

  private func write(apps: [App]) throws {
    let data = try encoder.encode(apps)
    try data.write(to: databaseURL)
  }
}

private struct WishlistDatabaseError: Error {}
