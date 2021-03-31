import Combine
import Domain
import Foundation

public final class SqliteAppRepository: AppRepository {
  private let sqlite: Sqlite

  public init(sqlite: Sqlite) throws {
    self.sqlite = sqlite
    try migrate()
  }

  public func fetchAll() throws -> [AppDetails] {
    try sqlite.run(
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
      try sqlite.execute(
        """
        REPLACE INTO app VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """,
        app.id,
        app.bundleID,
        app.title,
        app.description,
        app.seller,
        app.url,
        app.icon.small,
        app.icon.medium,
        app.icon.large,
        app.releaseDate,
        app.version.name,
        app.price.current.formatted,
        "AUD"
      )

      try sqlite.execute(
        """
        REPLACE INTO version VALUES (?, ?, ?, ?);
        """,
        app.id,
        app.version.name,
        app.version.date,
        app.version.notes
      )

      try sqlite.execute(
        """
        INSERT OR IGNORE INTO interaction VALUES (?, ?, ?, ?);
        """,
        app.id,
        app.firstAdded,
        app.lastViewed,
        0
      )

      try sqlite.execute(
        """
        REPLACE INTO notification VALUES (?, ?, ?);
        """,
        app.id,
        app.notifications.contains(.priceDrop),
        app.notifications.contains(.newVersion)
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
      try sqlite.execute(
        "DELETE FROM app WHERE id = ?;",
        id
      )
    }
    try sqlite.execute("COMMIT;")
  }

  public func viewedApp(id: AppID, at date: Date) throws {
    try sqlite.execute(
      """
      UPDATE interaction
      SET lastViewedDate = ?, viewCount = viewCount + 1
      WHERE appId = ?;
      """,
      date,
      id
    )
  }

  public func notify(id: AppID, for notifications: Set<ChangeNotification>) throws {
    try sqlite.execute(
      """
      REPLACE INTO notification VALUES (?, ?, ?);
      """,
      id,
      notifications.contains(.priceDrop),
      notifications.contains(.newVersion)
    )
  }

  public func versionHistory(id: AppID) throws -> [Version] {
    try sqlite.run(
      """
      SELECT name, releaseDate, releaseNotes
      FROM version
      WHERE appId = ?;
      """,
      id
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

extension AppID: SQLiteEncodable {}

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
        notes: try decoder.decode(String?.self)
      ),
      firstAdded: try decoder.decode(Date.self),
      lastViewed: try decoder.decode(Date?.self),
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
      notes: try decoder.decode(String?.self)
    )
  }
}
