import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

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
    guard info.hasItemsConforming(to: [UTType.url.identifier]) else {
      return false
    }

    info.loadURLs()
      .receive(on: DispatchQueue.main)
      .sink(receiveCompletion: { _ in }) { [acceptURLs] urls in
        acceptURLs(urls)
      }
      .store(in: &cancellables)

    return true
  }
}

private extension DropInfo {
  func loadURLs() -> AnyPublisher<[URL], Error> {
    let items = itemProviders(for: [UTType.url.identifier])
    let futureURLs = items.map { $0.loadURL() }
    return Publishers.Sequence(sequence: futureURLs)
      .flatMap { $0 }
      .collect()
      .eraseToAnyPublisher()
  }
}
