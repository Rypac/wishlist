import Combine
import Foundation
import SwiftUI

final class URLDropDelegate: DropDelegate {
  private let acceptURLs: ([URL]) -> Void
  private var cancellables = Set<AnyCancellable>()

  init(acceptURLs: @escaping ([URL]) -> Void) {
    self.acceptURLs = acceptURLs
  }

  deinit {
    cancellables.forEach { cancellable in
      cancellable.cancel()
    }
  }

  func performDrop(info: DropInfo) -> Bool {
    guard info.hasItemsConforming(to: [UTI.url]) else {
      return false
    }

    info.loadURLs()
      .sink(receiveCompletion: { _ in }) { [acceptURLs] urls in
        acceptURLs(urls)
      }
      .store(in: &cancellables)

    return true
  }
}

private extension DropInfo {
  func loadURLs() -> AnyPublisher<[URL], Error> {
    let items = itemProviders(for: [UTI.url])
    let futureURLs = items.map { $0.loadURL() }
    return Publishers.Sequence(sequence: futureURLs)
      .flatMap { $0 }
      .collect()
      .eraseToAnyPublisher()
  }
}

private extension NSItemProvider {
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
