import Foundation

public actor SharedTask<Success, Failure: Error> {
  private let operation: () async throws -> Success
  private var inProgressTask: Task<Success, Error>? = nil

  public init(operation: @escaping @Sendable () async throws -> Success) {
    self.operation = operation
  }

  deinit {
    inProgressTask?.cancel()
    inProgressTask = nil
  }

  public func run() async throws -> Success {
    if let task = inProgressTask {
      return try await task.value
    }

    let task = Task {
      try await operation()
    }
    inProgressTask = task

    let result: Result<Success, Error>
    do {
      result = .success(try await task.value)
    } catch {
      result = .failure(error)
    }

    inProgressTask = nil
    return try result.get()
  }
}
