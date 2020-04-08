import Foundation
import WishlistData

final class URLItemProvider: NSObject, Encodable, NSItemProviderWriting {
  let url: URL
  let title: String?

  init(url: URL, title: String? = nil) {
    self.url = url
    self.title = title
  }

  static var writableTypeIdentifiersForItemProvider: [String] {
    [
      UTI.url,
      UTI.plainText
    ]
  }

  func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
    switch typeIdentifier {
    case UTI.url:
      do {
        let data = try PropertyListEncoder().encode(URLDropRepresentation(url: url, title: title))
        completionHandler(data, nil)
      } catch {
        completionHandler(nil, error)
      }
    case UTI.plainText:
      if let data = url.absoluteString.data(using: .utf8) {
        completionHandler(data, nil)
      } else {
        completionHandler(nil, nil)
      }
    default:
      completionHandler(nil, nil)
    }
    return nil
  }
}

extension NSItemProvider {
  convenience init(app: App) {
    self.init(object: URLItemProvider(url: app.url, title: app.title))
    self.suggestedName = app.title
  }
}

private struct URLDropRepresentation: Encodable {
  let url: URL
  let title: String?

  func encode(to encoder: Encoder) throws {
    var container = encoder.unkeyedContainer()
    try container.encode(url.absoluteString)
    try container.encode("")
    try container.encode(metadata)
  }

  private var metadata: [String: String] {
    guard let title = title else {
      return [:]
    }
    return ["title": title]
  }
}
