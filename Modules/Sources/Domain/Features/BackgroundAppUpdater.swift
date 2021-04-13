import BackgroundTasks
import Combine
import Foundation

public protocol BackgroundTask: AnyObject {
  var identifier: String { get }
  var expirationHandler: (() -> Void)? { get set }
  func setTaskCompleted(success: Bool)
}

public struct BackgroundTaskConfiguration: Identifiable, Equatable {
  public let id: String
  public var frequency: TimeInterval

  public init(id: String, frequency: TimeInterval) {
    self.id = id
    self.frequency = frequency
  }
}

public struct BackgroundTaskEnvironment {
  public var submitTask: (BGTaskRequest) throws -> Void
  public var fetchApps: () throws -> [AppDetails]
  public var lookupApps: ([AppID]) -> AnyPublisher<[AppSummary], Error>
  public var saveUpdatedApps: ([AppDetails]) throws -> Void
  public var system: SystemEnvironment

  public init(
    submitTask: @escaping (BGTaskRequest) throws -> Void,
    fetchApps: @escaping () throws -> [AppDetails],
    lookupApps: @escaping ([AppID]) -> AnyPublisher<[AppSummary], Error>,
    saveUpdatedApps: @escaping ([AppDetails]) throws -> Void,
    system: SystemEnvironment
  ) {
    self.submitTask = submitTask
    self.fetchApps = fetchApps
    self.lookupApps = lookupApps
    self.saveUpdatedApps = saveUpdatedApps
    self.system = system
  }
}

public final class BackgroundAppUpdater {
  public let configuration: BackgroundTaskConfiguration
  private let environment: BackgroundTaskEnvironment

  private var cancellables = Set<AnyCancellable>()

  public init(configuration: BackgroundTaskConfiguration, environment: BackgroundTaskEnvironment) {
    self.configuration = configuration
    self.environment = environment
  }

  deinit {
    for cancellable in cancellables {
      cancellable.cancel()
    }
    cancellables.removeAll()
  }

  public func scheduleTask() throws {
    let request = BGAppRefreshTaskRequest(identifier: configuration.id)
    request.earliestBeginDate = environment.system.now().addingTimeInterval(configuration.frequency)
    try environment.submitTask(request)
  }

  public func run(task: BackgroundTask) {
    guard let apps = try? environment.fetchApps() else {
      task.setTaskCompleted(success: false)
      return
    }

    let cancellable = environment.lookupApps(apps.map(\.id))
      .map { latestApps in
        latestApps.reduce(into: [] as [AppDetails]) { updatedApps, latestApp in
          if var app = apps.first(where: { $0.id == latestApp.id }), latestApp.isUpdated(from: app) {
            app.applyUpdate(latestApp)
            updatedApps.append(app)
          }
        }
      }
      .receive(on: environment.system.mainQueue)
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            task.setTaskCompleted(success: true)
          case .failure:
            task.setTaskCompleted(success: false)
          }
        },
        receiveValue: { [environment] updatedApps in
          try? environment.saveUpdatedApps(updatedApps)
        }
      )

    task.expirationHandler = {
      task.setTaskCompleted(success: false)
      cancellable.cancel()
    }

    cancellables.insert(cancellable)

    try? scheduleTask()
  }
}
