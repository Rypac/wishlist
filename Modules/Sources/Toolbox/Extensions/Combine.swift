import Combine

extension Publisher {
  public static func just(_ value: Output) -> some Publisher<Output, Failure> {
    Just(value).setFailureType(to: Failure.self)
  }

  public static func empty(completeImmediately: Bool = true) -> some Publisher<Output, Failure> {
    Empty()
  }

  public static func never() -> some Publisher<Output, Failure> {
    Empty(completeImmediately: false)
  }
}

extension Publisher {
  public func asyncMap<T>(
    _ transform: @escaping (Output) async -> T
  ) -> Publishers.FlatMap<Future<T, Never>, Self> {
    flatMap { value in
      Future { promise in
        Task {
          promise(.success(await transform(value)))
        }
      }
    }
  }

  public func asyncTryMap<T>(
    _ transform: @escaping (Output) async throws -> T
  ) -> Publishers.FlatMap<Future<T, Error>, Self> {
    flatMap { value in
      Future { promise in
        Task {
          do {
            promise(.success(try await transform(value)))
          } catch {
            promise(.failure(error))
          }
        }
      }
    }
  }

  public func asyncTryMap<T>(
    _ transform: @escaping (Output) async throws -> T
  ) -> Publishers.FlatMap<Future<T, Error>, Publishers.SetFailureType<Self, Error>> {
    flatMap { value in
      Future { promise in
        Task {
          do {
            promise(.success(try await transform(value)))
          } catch {
            promise(.failure(error))
          }
        }
      }
    }
  }
}
