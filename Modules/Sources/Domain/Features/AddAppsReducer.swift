import Combine
import Foundation
import Toolbox

public struct AppAdder {
  public struct Environment {
    public var loadApps: (_ ids: [AppID]) async throws -> [AppSummary]
    public var saveApps: (_ apps: [AppDetails]) async throws -> Void
    public var now: () -> Date

    public init(
      loadApps: @escaping (_ ids: [AppID]) async throws -> [AppSummary],
      saveApps: @escaping (_ apps: [AppDetails]) async throws -> Void,
      now: @escaping () -> Date
    ) {
      self.loadApps = loadApps
      self.saveApps = saveApps
      self.now = now
    }
  }

  public let environment: Environment

  public init(environment: Environment) {
    self.environment = environment
  }

  public func addApps(ids: [AppID]) async throws {
    let summaries = try await environment.loadApps(ids)
    let now = environment.now()
    let apps = summaries.map { AppDetails(summary: $0, firstAdded: now, lastViewed: nil) }
    try await environment.saveApps(apps)
  }

  public func addApps(from urls: [URL]) async throws {
    try await addApps(ids: extractAppIDs(from: urls))
  }
}

private func extractAppIDs(from urls: [URL]) -> [AppID] {
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

    return Int(url[range]).map(AppID.init(rawValue:))
  }
}
