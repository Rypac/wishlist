import Domain
import Foundation

public final class SQLiteAppPersistence: AppPersistence {
  private let sqlite: SQLite

  public init(sqlite: SQLite) throws {
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
        interaction.lastViewedDate
      FROM app
      LEFT JOIN version
        ON app.id = version.appId AND app.version = version.name
      LEFT JOIN interaction
        ON app.id = interaction.appId;
      """
    )
  }

  public func fetch(id: AppID) throws -> AppDetails? {
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
        interaction.lastViewedDate
      FROM app
      LEFT JOIN version
        ON app.id = version.appId AND app.version = version.name
      LEFT JOIN interaction
        ON app.id = interaction.appId
      WHERE id = ?
      LIMIT 1;
      """,
      id
    ).first
  }

  public func add(_ app: AppDetails) throws {
    try sqlite.execute(literal:
      """
      INSERT INTO app VALUES (
        \(app.id),
        \(app.bundleID),
        \(app.title),
        \(app.description),
        \(app.seller),
        \(app.url),
        \(app.icon.small),
        \(app.icon.medium),
        \(app.icon.large),
        \(app.releaseDate),
        \(app.version.name),
        \(app.price.current.formatted),
        \("AUD")
      )
      ON CONFLICT(id) DO UPDATE SET
        bundleId = excluded.bundleId,
        title = excluded.title,
        description = excluded.description,
        seller = excluded.seller,
        url = excluded.url,
        iconSmallUrl = excluded.iconSmallUrl,
        iconMediumUrl = excluded.iconMediumUrl,
        iconLargeUrl = excluded.iconLargeUrl,
        releaseDate = excluded.releaseDate,
        version = excluded.version,
        price = excluded.price,
        currency = excluded.currency;
      """
    )

    try sqlite.execute(literal:
      """
      REPLACE INTO version VALUES (
        \(app.id),
        \(app.version.name),
        \(app.version.date),
        \(app.version.notes)
      );
      """
    )

    try sqlite.execute(literal:
      """
      REPLACE INTO interaction VALUES (
        \(app.id),
        \(app.firstAdded),
        \(app.lastViewed)
      );
      """
    )

    try sqlite.execute(literal:
      """
      INSERT OR IGNORE INTO notification VALUES (
        \(app.id),
        \(app.price.current.value > 0),
        \(true)
      );
      """
    )
  }

  public func add(_ apps: [AppDetails]) throws {
    try sqlite.transaction {
      for app in apps {
        try add(app)
      }
    }
  }

  public func delete(id: AppID) throws {
    try sqlite.execute(literal: "DELETE FROM app WHERE id = \(id);")
  }

  public func delete(ids: [AppID]) throws {
    try sqlite.transaction {
      for id in ids {
        try delete(id: id)
      }
    }
  }

  public func deleteAll() throws {
    try sqlite.execute(sql: "DELETE FROM app;")
  }

  public func viewedApp(id: AppID, at date: Date) throws {
    try sqlite.execute(literal:
      """
      UPDATE interaction
      SET lastViewedDate = \(date)
      WHERE appId = \(id);
      """
    )
  }

  public func notifyApp(id: AppID, for notifications: Set<ChangeNotification>) throws {
    try sqlite.execute(literal:
      """
      UPDATE notification
      SET
        priceDrop = \(notifications.contains(.priceDrop)),
        newVersion = \(notifications.contains(.newVersion))
      WHERE appId = \(id);
      """
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

private extension SQLiteAppPersistence {
  func migrate() throws {
    try sqlite.execute(sql:
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
        lastViewedDate TEXT
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

extension AppID: SQLiteCodable {}

extension AppDetails: SQLiteDecodable {
  public init(from decoder: inout SQLiteDecoder) throws {
    self.init(
      id: try decoder.decode(AppID.self),
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
      version: try Version(from: &decoder),
      firstAdded: try decoder.decode(Date.self),
      lastViewed: try decoder.decode(Date?.self)
    )
  }
}

extension Version: SQLiteDecodable {
  public init(from decoder: inout SQLiteDecoder) throws {
    self.init(
      name: try decoder.decode(String.self),
      date: try decoder.decode(Date.self),
      notes: try decoder.decode(String?.self)
    )
  }
}
