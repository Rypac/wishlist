import Combine
import Domain
import Foundation

public final class SqliteAppRepository: AppRepository {
  private let sqlite: Sqlite
  private let utcISODateFormatter = ISO8601DateFormatter()

  public init(sqlite: Sqlite) throws {
    self.sqlite = sqlite
    try migrate()
  }

  public func fetchAll() throws -> [AppDetails] {
    try sqlite.runDecoding(
      """
      SELECT
        app.id,
        app.title,
        app.seller,
        app.description,
        app.url,
        app.iconSmallUrl,
        app.iconMediumUrl,
        app.iconLargeUrl,
        app.bundleId,
        app.releaseDate,
        app.price,
        version.name,
        version.releaseDate,
        version.releaseNotes,
        interaction.firstAddedDate,
        interaction.lastViewedDate,
        notification.priceDrop,
        notification.newVersion
      FROM app
      LEFT JOIN version
        ON app.id = version.appId AND app.version = version.name
      LEFT JOIN interaction
        ON app.id = interaction.appId
      LEFT JOIN notification
        ON app.id = notification.appId;
      """
    )
  }

  public func add(_ apps: [AppDetails]) throws {
    try sqlite.execute("BEGIN;")
    for app in apps {
      try sqlite.run(
        """
        REPLACE INTO app VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """,
        .integer(Int64(app.id.rawValue)),
        .text(app.bundleID),
        .text(app.title),
        .text(app.description),
        .text(app.seller),
        .text(app.url.absoluteString),
        .text(app.icon.small.absoluteString),
        .text(app.icon.medium.absoluteString),
        .text(app.icon.large.absoluteString),
        .text(utcISODateFormatter.string(from: app.releaseDate)),
        .text(app.version.name),
        .text(app.price.current.formatted),
        "AUD"
      )

      try sqlite.run(
        """
        REPLACE INTO version VALUES (?, ?, ?, ?);
        """,
        .integer(Int64(app.id.rawValue)),
        .text(app.version.name),
        .text(utcISODateFormatter.string(from: app.version.date)),
        app.version.notes.map(Sqlite.Datatype.text) ?? .null
      )

      try sqlite.run(
        """
        INSERT OR IGNORE INTO interaction VALUES (?, ?, ?, ?);
        """,
        .integer(Int64(app.id.rawValue)),
        .text(utcISODateFormatter.string(from: app.firstAdded)),
        app.lastViewed.map { .text(utcISODateFormatter.string(from: $0)) } ?? .null,
        0
      )

      try sqlite.run(
        """
        REPLACE INTO notification VALUES (?, ?, ?);
        """,
        .integer(Int64(app.id.rawValue)),
        .integer(app.notifications.contains(.priceDrop) ? 1 : 0),
        .integer(app.notifications.contains(.newVersion) ? 1 : 0)
      )
    }
    try sqlite.execute("COMMIT;")
  }

  public func deleteAll() throws {
    try sqlite.execute("DELETE FROM app;")
  }

  public func delete(ids: [AppID]) throws {
    try sqlite.execute("BEGIN;")
    for id in ids {
      try sqlite.run(
        "DELETE FROM app WHERE id = ?;",
        .integer(Int64(id.rawValue))
      )
    }
    try sqlite.execute("COMMIT;")
  }

  public func viewedApp(id: AppID, at date: Date) throws {
    try sqlite.run(
      """
      UPDATE interaction
      SET lastViewedDate = ?, viewCount = viewCount + 1
      WHERE appId = ?;
      """,
      .text(utcISODateFormatter.string(from: date)),
      .integer(Int64(id.rawValue))
    )
  }

  public func notify(id: AppID, for notifications: Set<ChangeNotification>) throws {
    try sqlite.run(
      """
      REPLACE INTO notification VALUES (?, ?, ?);
      """,
      .integer(Int64(id.rawValue)),
      .integer(notifications.contains(.priceDrop) ? 1 : 0),
      .integer(notifications.contains(.newVersion) ? 1 : 0)
    )
  }

  public func versionHistory(id: AppID) throws -> [Version] {
    try sqlite.runDecoding(
      """
      SELECT name, releaseDate, releaseNotes
      FROM version
      WHERE appId = ?;
      """,
      .integer(Int64(id.rawValue))
    )
  }
}

private extension SqliteAppRepository {
  func migrate() throws {
    try sqlite.execute(
      """
      PRAGMA foreign_keys = ON;

      CREATE TABLE IF NOT EXISTS app (
        id INTEGER PRIMARY KEY,
        bundleId TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        seller TEXT NOT NULL,
        url TEXT NOT NULL,
        iconSmallUrl TEXT NOT NULL,
        iconMediumUrl TEXT NOT NULL,
        iconLargeUrl TEXT NOT NULL,
        releaseDate TEXT NOT NULL,
        version TEXT NOT NULL,
        price TEXT NOT NULL,
        currency TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS version (
        appId INTEGER NOT NULL REFERENCES app ON DELETE CASCADE,
        name TEXT NOT NULL,
        releaseDate TEXT NOT NULL,
        releaseNotes TEXT,
        PRIMARY KEY (appId, name)
      );

      CREATE TABLE IF NOT EXISTS price (
        appId INTEGER NOT NULL REFERENCES app ON DELETE CASCADE,
        price TEXT NOT NULL,
        currency TEXT NOT NULL,
        recordedDate TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS interaction (
        appId INTEGER PRIMARY KEY REFERENCES app ON DELETE CASCADE,
        firstAddedDate TEXT NOT NULL,
        lastViewedDate TEXT,
        viewCount INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS notification (
        appId INTEGER PRIMARY KEY REFERENCES app ON DELETE CASCADE,
        priceDrop BOOLEAN NOT NULL,
        newVersion BOOLEAN NOT NULL
      );
      """
    )
  }
}

extension AppDetails: SQLiteRowDecodable {
  public init(from decoder: SQLiteDecoder) throws {
    var decoder = decoder
    self.init(
      id: AppID(rawValue: try decoder.decode(Int.self)),
      title: try decoder.decode(String.self),
      seller: try decoder.decode(String.self),
      description: try decoder.decode(String.self),
      url: try decoder.decode(URL.self),
      icon: Icon(
        small: try decoder.decode(URL.self),
        medium: try decoder.decode(URL.self),
        large: try decoder.decode(URL.self)
      ),
      bundleID: try decoder.decode(String.self),
      releaseDate: try decoder.decode(Date.self),
      price: Tracked(current: Price(value: 0, formatted: try decoder.decode(String.self))),
      version: Version(
        name: try decoder.decode(String.self),
        date: try decoder.decode(Date.self),
        notes: try decoder.decodeIfPresent(String.self)
      ),
      firstAdded: try decoder.decode(Date.self),
      lastViewed: try decoder.decodeIfPresent(Date.self),
      notifications: try {
        var notifications = Set<ChangeNotification>()
        if try decoder.decode(Bool.self) {
          notifications.insert(.priceDrop)
        }
        if try decoder.decode(Bool.self) {
          notifications.insert(.newVersion)
        }
        return notifications
      }()
    )
  }
}

extension Version: SQLiteRowDecodable {
  public init(from decoder: SQLiteDecoder) throws {
    var decoder = decoder
    self.init(
      name: try decoder.decode(String.self),
      date: try decoder.decode(Date.self),
      notes: try decoder.decodeIfPresent(String.self)
    )
  }
}
