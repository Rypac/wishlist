import Foundation

public enum AppStore {
  public static func extractIDs(from urls: [URL]) -> [Int] {
    let idMatch = "id"
    let appStoreURL = "https?://(?:itunes|apps).apple.com/.*/id(?<\(idMatch)>\\d+)"
    guard let regex = try? NSRegularExpression(pattern: appStoreURL, options: []) else {
      return []
    }

    return urls.compactMap { url in
      let url = url.absoluteString
      let entireRange = NSRange(url.startIndex..<url.endIndex, in: url)
      guard let match = regex.firstMatch(in: url, options: [], range: entireRange) else {
        return nil
      }

      let idRange = match.range(withName: idMatch)
      guard idRange.location != NSNotFound, let range = Range(idRange, in: url) else {
        return nil
      }

      return Int(url[range])
    }
  }
}
