import Combine
import ComposableArchitecture
import Foundation

public struct AddAppsError: Error, Equatable {}

public struct AddAppsState: Equatable {
  public var addingApps: Bool

  public init(addingApps: Bool = false) {
    self.addingApps = addingApps
  }
}

public enum AddAppsAction: Equatable {
  case addApps([AppID])
  case addAppsFromURLs([URL])
  case addAppsResponse(Result<[AppSummary], AddAppsError>)
  case cancelAddingApps
}

public struct AddAppsEnvironment {
  public var loadApps: ([AppID]) -> AnyPublisher<[AppSummary], Error>
  public var saveApps: ([AppSummary]) -> Void

  public init(
    loadApps: @escaping ([AppID]) -> AnyPublisher<[AppSummary], Error>,
    saveApps: @escaping ([AppSummary]) -> Void
  ) {
    self.loadApps = loadApps
    self.saveApps = saveApps
  }
}

public let addAppsReducer = Reducer<AddAppsState, AddAppsAction, SystemEnvironment<AddAppsEnvironment>> { state, action, environment in
  struct CancelAddAppsID: Hashable {}
  switch action {
  case let .addApps(ids):
    state.addingApps = true
    return environment.loadApps(ids)
      .receive(on: environment.mainQueue())
      .mapError { _ in AddAppsError() }
      .catchToEffect()
      .map(AddAppsAction.addAppsResponse)
      .cancellable(id: CancelAddAppsID(), cancelInFlight: true)

  case let .addAppsFromURLs(urls):
    let ids = extractAppIDs(from: urls)
    return ids.isEmpty ? .none : Effect(value: .addApps(ids))

  case let .addAppsResponse(.success(apps)):
    state.addingApps = false
    return .fireAndForget {
      environment.saveApps(apps)
    }

  case .addAppsResponse(.failure):
    state.addingApps = false
    return .none

  case .cancelAddingApps:
    state.addingApps = false
    return .cancel(id: CancelAddAppsID())
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
