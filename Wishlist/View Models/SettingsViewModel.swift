import Combine
import SwiftUI

final class SettingsViewModel: ObservableObject {
  let objectWillChange = PassthroughSubject<Void, Never>()

  private let settings: ObservableSettings
  private let cancellable: Cancellable

  init(settings: ObservableSettings) {
    self.settings = settings
    self.cancellable = settings.didChange
      .subscribe(objectWillChange)
  }

  deinit {
    cancellable.cancel()
  }
}

extension SettingsViewModel {
  var sortOrder: SortOrder {
    get { settings.sortOrder }
    set { settings.sortOrder = newValue }
  }
}
