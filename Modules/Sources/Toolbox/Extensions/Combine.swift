import Combine

extension AnyPublisher {
  public static func just(_ value: Output) -> AnyPublisher<Output, Failure> {
    Just(value).setFailureType(to: Failure.self).eraseToAnyPublisher()
  }

  public static func empty(completeImmediately: Bool = true) -> AnyPublisher<Output, Failure> {
    Empty().eraseToAnyPublisher()
  }

  public static func never() -> AnyPublisher<Output, Failure> {
    Empty(completeImmediately: false).eraseToAnyPublisher()
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
