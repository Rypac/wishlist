import Foundation

public final class AppAdder {
  private let loadApps: (_ ids: [AppID]) async throws -> [AppSummary]
  private let saveApps: (_ apps: [AppDetails]) async throws -> Void
  private let now: () -> Date

  public init(
    loadApps: @escaping (_ ids: [AppID]) async throws -> [AppSummary],
    saveApps: @escaping (_ apps: [AppDetails]) async throws -> Void,
    now: @escaping () -> Date
  ) {
    self.loadApps = loadApps
    self.saveApps = saveApps
    self.now = now
  }

  public func addApps(ids: [AppID]) async throws {
    let summaries = try await loadApps(ids)
    let now = now()
    let apps = summaries.map { AppDetails(summary: $0, firstAdded: now, lastViewed: nil) }
    try await saveApps(apps)
  }

  public func addApps(from urls: [URL]) async throws {
    let idMatch = "id"
    let appStoreURL = "https?://(?:itunes|apps).apple.com/.*/id(?<\(idMatch)>\\d+)"
    let regex = try NSRegularExpression(pattern: appStoreURL, options: [])

    let ids = urls.compactMap { url -> AppID? in
      let url = url.absoluteString
      let entireRange = NSRange(url.startIndex..<url.endIndex, in: url)
      guard let match = regex.firstMatch(in: url, options: [], range: entireRange) else {
        return nil
      }

      let idRange = match.range(withName: idMatch)
      guard idRange.location != NSNotFound, let range = Range(idRange, in: url) else {
        return nil
      }

      return Int(url[range]).map(AppID.init(rawValue:))
    }

    try await addApps(ids: ids)
  }
}
