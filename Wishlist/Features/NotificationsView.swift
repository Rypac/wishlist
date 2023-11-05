import Combine
import Domain
import Foundation
import SwiftUI
import UserDefaults

final class NotificationsModel: ObservableObject {
  private let notificationsPreferences: UserDefault<Bool>

  @Published var enabled: Bool {
    willSet {
      notificationsPreferences.wrappedValue = newValue
    }
  }
  @Published var notifications = Set<ChangeNotification>()

  init(notificationsEnabled: UserDefault<Bool>) {
    self.notificationsPreferences = notificationsEnabled
    self.enabled = notificationsEnabled.wrappedValue
    self.notificationsPreferences.publisher().assign(to: &$enabled)
  }
}

struct NotificationsView: View {
  @StateObject var model: NotificationsModel

  var body: some View {
    Toggle("Enable Notifications", isOn: $model.enabled.animation())

    if model.enabled {
      ConfigureNotificationsView(
        notification: .priceDrop,
        enabled: $model.notifications.contains(.priceDrop)
      )
      ConfigureNotificationsView(
        notification: .newVersion,
        enabled: $model.notifications.contains(.newVersion)
      )
    }
  }
}

private struct ConfigureNotificationsView: View {
  let notification: ChangeNotification
  @Binding var enabled: Bool

  var body: some View {
    NavigationLink {
      List {
        Section {
          Toggle("Enable Notifications", isOn: $enabled)
        }
      }
      .navigationTitle(notification.title)
    } label: {
      Text(notification.title)
        .badge(enabled ? "Enabled" : "Disabled")
    }
  }
}

private extension ChangeNotification {
  var title: String {
    switch self {
    case .newVersion: "Updates"
    case .priceDrop: "Price Drops"
    }
  }
}
