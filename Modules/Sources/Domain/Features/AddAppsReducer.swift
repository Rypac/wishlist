import Combine
import ComposableArchitecture
import Foundation

public struct AddAppsError: Error, Equatable {}

public struct AddAppsState: Equatable {
  public var apps: [AppDetails]

  public init(apps: [AppDetails]) {
    self.apps = apps
  }
}

public enum AddAppsAction: Equatable {
  case addApps([AppID])
  case addAppsFromURLs([URL])
  case addAppsResponse(Result<[AppSummary], AddAppsError>)
}

public struct AddAppsEnvironment {
  public var loadApps: ([AppID]) -> AnyPublisher<[AppSummary], Error>

  public init(loadApps: @escaping ([AppID]) -> AnyPublisher<[AppSummary], Error>) {
    self.loadApps = loadApps
  }
}

public let addAppsReducer = Reducer<AddAppsState, AddAppsAction, SystemEnvironment<AddAppsEnvironment>> { state, action, environment in
  switch action {
  case let .addApps(ids):
    return environment.loadApps(ids)
      .receive(on: environment.mainQueue())
      .mapError { _ in AddAppsError() }
      .catchToEffect()
      .map(AddAppsAction.addAppsResponse)

  case let .addAppsFromURLs(urls):
    let ids = extractAppIDs(from: urls)
    return ids.isEmpty ? .none : Effect(value: .addApps(ids))

  case let .addAppsResponse(.success(apps)):
    apps.forEach { app in
      if let index = state.apps.firstIndex(where: { $0.id == app.id }) {
        state.apps[index].applyUpdate(app)
      }
    }
    return .none

  case .addAppsResponse:
    return .none
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
