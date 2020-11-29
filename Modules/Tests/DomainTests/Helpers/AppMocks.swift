import Foundation
import Domain
import Toolbox

extension AppDetails {
  init(_ app: AppSummary, firstAdded: Date, lastViewed: Date? = nil, notifications: Set<ChangeNotification> = []) {
    self.init(
      id: app.id,
      title: app.title,
      seller: app.seller,
      description: app.description,
      url: app.url,
      icon: app.icon,
      bundleID: app.bundleID,
      releaseDate: app.releaseDate,
      price: Tracked(current: app.price),
      version: app.version,
      firstAdded: firstAdded,
      lastViewed: lastViewed,
      notifications: notifications
    )
  }
}

extension AppSummary {
  static var bear: AppSummary {
    AppSummary(
      id: 1016366447,
      title: "Bear",
      seller: "Shiny Frog Ltd.",
      description: "Bear is a focused, flexible notes app.",
      url: URL(string: "https://apps.apple.com/au/app/bear/id1016366447")!,
      icon: .mock(url: URL(string: "https://is5-ssl.mzstatic.com/image/thumb/Purple123/v4/25/87/40/25874033-d5f1-0fc1-45ce-2c2c3a51cba1/source/60x60bb.jpg")!),
      price: Price(value: 0, formatted: "Free"),
      version: Version(
        name: "1.7.14",
        date: Date(timeIntervalSinceReferenceDate: 610443200),
        notes: nil
      ),
      bundleID: "net.shinyfrog.bear-iOS",
      releaseDate: Date(timeIntervalSinceReferenceDate: 499816034)
    )
  }

  static var things: AppSummary {
    AppSummary(
      id: 904237743,
      title: "Things 3",
      seller: "Cultured Code GmbH & Co. KG",
      description: "Meet the all-new Things!",
      url: URL(string: "https://apps.apple.com/au/app/things-3/id904237743")!,
      icon: .mock(url: URL(string: "https://is3-ssl.mzstatic.com/image/thumb/Purple123/v4/91/1b/fb/911bfb4f-003c-c861-0a81-a211018bbfb3/source/60x60bb.jpg")!),
      price: Price(value: 14.99, formatted: "$14.99"),
      version: Version(
        name: "3.12.4",
        date: Date(timeIntervalSinceReferenceDate: 610893480),
        notes: nil
      ),
      bundleID: "com.culturedcode.ThingsiPhone",
      releaseDate: Date(timeIntervalSinceReferenceDate: 516813030)
    )
  }
}

extension Icon {
  static func mock(url: URL) -> Self {
    Self(small: url, medium: url, large: url)
  }
}
