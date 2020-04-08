import Combine
import Foundation

public extension NSItemProvider {
  func loadURL() -> Future<URL, Error> {
    Future { [item = self] promise in
      _ = item.loadObject(ofClass: URL.self) { url, error in
        if let url = url {
          promise(.success(url))
        } else {
          promise(.failure(error ?? LoadURLError()))
        }
      }
    }
  }
}

private struct LoadURLError: Error {}
