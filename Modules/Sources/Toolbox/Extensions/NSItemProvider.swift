import Combine
import Foundation

extension NSItemProvider {
  public func loadURL() async throws -> URL {
    try await withUnsafeThrowingContinuation { [item = self] continuation in
      _ = item.loadObject(ofClass: URL.self) { url, error in
        if let url = url {
          continuation.resume(returning: url)
        } else {
          continuation.resume(throwing: error ?? LoadURLError())
        }
      }
    }
  }

  public func loadURLPublisher() -> AnyPublisher<URL, Error> {
    Deferred {
      Future { [item = self] promise in
        _ = item.loadObject(ofClass: URL.self) { url, error in
          if let url = url {
            promise(.success(url))
          } else {
            promise(.failure(error ?? LoadURLError()))
          }
        }
      }
    }.eraseToAnyPublisher()
  }
}

private struct LoadURLError: Error {}
