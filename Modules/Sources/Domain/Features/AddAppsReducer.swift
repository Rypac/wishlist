import Combine
import Foundation
import Toolbox

public struct AppAdder {
  public struct Environment {
    public var loadApps: (_ ids: [AppID]) -> AnyPublisher<[AppSummary], Error>
    public var saveApps: (_ apps: [AppDetails]) throws -> Void

    public init(
      loadApps: @escaping (_ ids: [AppID]) -> AnyPublisher<[AppSummary], Error>,
      saveApps: @escaping (_ apps: [AppDetails]) throws -> Void
    ) {
      self.loadApps = loadApps
      self.saveApps = saveApps
    }
  }

  public var environment: SystemEnvironment<Environment>

  public init(environment: SystemEnvironment<Environment>) {
    self.environment = environment
  }

  public func addApps(ids: [AppID]) -> AnyPublisher<Bool, Never> {
    environment.loadApps(ids)
      .receive(on: environment.mainQueue())
      .tryMap { summaries in
        let now = environment.now()
        let apps = summaries.map { AppDetails(summary: $0, firstAdded: now, lastViewed: nil) }
        try environment.saveApps(apps)
        return true
      }
      .catch { _ in Just(false) }
      .eraseToAnyPublisher()
  }

  public func addApps(from urls: [URL]) -> AnyPublisher<Bool, Never> {
    addApps(ids: extractAppIDs(from: urls))
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
