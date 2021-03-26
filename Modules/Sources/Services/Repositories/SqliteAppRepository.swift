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
    let utcISODateFormatter = ISO8601DateFormatter()
    let results = try sqlite.run(
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

    return results.compactMap { row in
      guard
        case let .integer(id) = row[0],
        case let .text(title) = row[1],
        case let .text(seller) = row[2],
        case let .text(description) = row[3],
        case let .text(url) = row[4],
        case let .text(iconSmallUrl) = row[5],
        case let .text(iconMediumUrl) = row[6],
        case let .text(iconLargeUrl) = row[7],
        case let .text(bundleId) = row[8],
        case let .text(releaseDate) = row[9],
        case let .text(price) = row[10],
        case let .text(version) = row[11],
        case let .text(updateDate) = row[12],
        case let .text(firstAddedDate) = row[14],
        case let .integer(priceDrop) = row[16],
        case let .integer(newVersion) = row[17]
      else {
        return nil
      }

      let releaseNotes: String?
      if case let .text(notes) = row[13] {
        releaseNotes = notes
      } else {
        releaseNotes = nil
      }

      let lastViewedDate: Date?
      if case let .text(date) = row[15] {
        lastViewedDate = utcISODateFormatter.date(from: date)
      } else {
        lastViewedDate = nil
      }

      var notifications = Set<ChangeNotification>()
      if priceDrop == 1 {
        notifications.insert(.priceDrop)
      }
      if newVersion == 1 {
        notifications.insert(.newVersion)
      }

      return AppDetails(
        id: AppDetails.ID(rawValue: Int(id)),
        title: title,
        seller: seller,
        description: description,
        url: URL(string: url)!,
        icon: Icon(
          small: URL(string: iconSmallUrl)!,
          medium: URL(string: iconMediumUrl)!,
          large: URL(string: iconLargeUrl)!
        ),
        bundleID: bundleId,
        releaseDate: utcISODateFormatter.date(from: releaseDate)!,
        price: Tracked(current: Price(value: 0, formatted: price)),
        version: Version(
          name: version,
          date: utcISODateFormatter.date(from: updateDate)!,
          notes: releaseNotes
        ),
        firstAdded: utcISODateFormatter.date(from: firstAddedDate)!,
        lastViewed: lastViewedDate,
        notifications: notifications
      )
    }
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
        nil,
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
    let utcISODateFormatter = ISO8601DateFormatter()
    let results = try sqlite.run(
      """
      SELECT name, releaseDate, releaseNotes
      FROM version
      WHERE appId = ?;
      """,
      .integer(Int64(id.rawValue))
    )

    return results.compactMap { row in
      guard
        case let .text(name) = row[0],
        case let .text(date) = row[1],
        let releaseDate = utcISODateFormatter.date(from: date)
      else {
        return nil
      }

      let releaseNotes: String?
      if case let .text(notes) = row[2] {
        releaseNotes = notes
      } else {
        releaseNotes = nil
      }

      return Version(name: name, date: releaseDate, notes: releaseNotes)
    }
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
        firstAddedDate TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
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
