import BackgroundTasks
import Combine
import WishlistCore

private struct FailedToRegisterTaskError: Swift.Error {}

public extension BGTaskScheduler {
  func register(task: BackgroundTask) -> AnyPublisher<BGTask, Swift.Error> {
    let taskSubject = PassthroughSubject<BGTask, Swift.Error>()

    let registeredTask = BGTaskScheduler.shared.register(forTaskWithIdentifier: task.id, using: nil) { task in
      taskSubject.send(task)
    }

    if !registeredTask {
      taskSubject.send(completion: .failure(FailedToRegisterTaskError()))
    }

    return taskSubject.eraseToAnyPublisher()
  }
}
