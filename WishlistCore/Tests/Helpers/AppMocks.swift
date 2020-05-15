import Foundation
import WishlistFoundation

extension App {
  static var bear: App {
    App(
      id: 1016366447,
      title: "Bear",
      seller: "Shiny Frog Ltd.",
      description: "Bear is a focused, flexible notes app.",
      url: URL(string: "https://apps.apple.com/au/app/bear/id1016366447")!,
      icon: .mock(url: URL(string: "https://is5-ssl.mzstatic.com/image/thumb/Purple123/v4/25/87/40/25874033-d5f1-0fc1-45ce-2c2c3a51cba1/source/60x60bb.jpg")!),
      price: .free,
      bundleID: "net.shinyfrog.bear-iOS",
      version: "1.7.14",
      releaseDate: Date(timeIntervalSinceReferenceDate: 499816034),
      updateDate: Date(timeIntervalSinceReferenceDate: 610443200),
      releaseNotes: nil
    )
  }

  static var things: App {
    App(
      id: 904237743,
      title: "Things 3",
      seller: "Cultured Code GmbH & Co. KG",
      description: "Meet the all-new Things!",
      url: URL(string: "https://apps.apple.com/au/app/things-3/id904237743")!,
      icon: .mock(url: URL(string: "https://is3-ssl.mzstatic.com/image/thumb/Purple123/v4/91/1b/fb/911bfb4f-003c-c861-0a81-a211018bbfb3/source/60x60bb.jpg")!),
      price: Price(value: 14.99, formatted: "14.99"),
      bundleID: "com.culturedcode.ThingsiPhone",
      version: "3.12.4",
      releaseDate: Date(timeIntervalSinceReferenceDate: 516813030),
      updateDate: Date(timeIntervalSinceReferenceDate: 610893480),
      releaseNotes: nil
    )
  }
}

extension App.Icon {
  static func mock(url: URL) -> Self {
    Self(small: url, medium: url, large: url)
  }
}

extension App.Price {
  static var free: Self {
    Self(value: 0, formatted: "Free")
  }
}

