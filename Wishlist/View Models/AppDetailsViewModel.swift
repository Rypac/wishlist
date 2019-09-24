import Combine
import SwiftUI

final class AppDetailsViewModel: ObservableObject {
  let objectWillChange = PassthroughSubject<Void, Never>()

  private let app: App

  init(app: App) {
    self.app = app
  }
}

extension AppDetailsViewModel {
  var title: String { app.title }
  var author: String { app.author }
  var description: String { app.description }
  var url: URL { app.url }
}
