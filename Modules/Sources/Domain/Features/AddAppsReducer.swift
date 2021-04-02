import Combine
import ComposableArchitecture
import Foundation
import Toolbox

public struct AddAppsError: Error, Equatable {}

public struct AddAppsState: Equatable {
  public var apps: IdentifiedArrayOf<AppDetails>
  public var addingApps: Bool

  public init(apps: IdentifiedArrayOf<AppDetails>, addingApps: Bool = false) {
    self.apps = apps
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
  public var saveApps: ([AppDetails]) throws -> Void

  public init(
    loadApps: @escaping ([AppID]) -> AnyPublisher<[AppSummary], Error>,
    saveApps: @escaping ([AppDetails]) throws -> Void
  ) {
    self.loadApps = loadApps
    self.saveApps = saveApps
  }
}

public let addAppsReducer = Reducer<AddAppsState, AddAppsAction, SystemEnvironment<AddAppsEnvironment>> { state, action, environment in
  struct CancelAddAppsID: Hashable {}
  switch action {
  case let .addApps(ids):
    let newIds = Set(ids).subtracting(state.apps.ids)
    if newIds.isEmpty {
      return .none
    }

    state.addingApps = true
    return environment.loadApps(Array(newIds))
      .receive(on: environment.mainQueue())
      .mapError { _ in AddAppsError() }
      .catchToEffect()
      .map(AddAppsAction.addAppsResponse)
      .cancellable(id: CancelAddAppsID(), cancelInFlight: true)

  case let .addAppsFromURLs(urls):
    return .none
//    let ids = extractAppIDs(from: urls)
//    return ids.isEmpty ? .none : Effect(value: .addApps(ids))

  case let .addAppsResponse(.success(newApps)):
    state.addingApps = false
    if newApps.isEmpty {
      return .none
    }

    let now = environment.now()
    let newApps = newApps.map { AppDetails($0, firstAdded: now) }
    for newApp in newApps where state.apps[id: newApp.id] == nil {
      state.apps.append(newApp)
    }

    return .fireAndForget {
      try? environment.saveApps(newApps)
    }

  case .addAppsResponse(.failure):
    state.addingApps = false
    return .none

  case .cancelAddingApps:
    state.addingApps = false
    return .cancel(id: CancelAddAppsID())
  }
}

extension AddAppsEnvironment {
  public func loadApps(from urls: [URL]) -> AnyPublisher<[AppSummary], Error> {
    let idMatch = "id"
    let appStoreURL = "https?://(?:itunes|apps).apple.com/.*/id(?<\(idMatch)>\\d+)"
    guard let regex = try? NSRegularExpression(pattern: appStoreURL, options: []) else {
      return .just([])
    }

    let appIds = urls.compactMap { url -> AppID? in
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

    if appIds.isEmpty {
      return .just([])
    }

    return loadApps(appIds)
  }
}

public struct AppAdder {
  public var environment: SystemEnvironment<AddAppsEnvironment>

  public init(environment: SystemEnvironment<AddAppsEnvironment>) {
    self.environment = environment
  }

  public func addApps(ids: [AppID]) -> AnyPublisher<Bool, Never> {
    environment.loadApps(ids)
      .receive(on: environment.mainQueue())
      .tryMap { summaries in
        let now = environment.now()
        let apps = summaries.map { AppDetails($0, firstAdded: now) }
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
