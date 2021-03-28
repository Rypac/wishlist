import Combine
import Domain
import Foundation
import SwiftUI

final class NotificationsModel: ObservableObject {
  @Published var enabled = false
  @Published private var notifications = Set<ChangeNotification>()

  func enabled(for notification: ChangeNotification) -> Binding<Bool> {
    Binding(
      get: { self.notifications.contains(notification) },
      set: { enable in
        if enable {
          self.notifications.insert(notification)
        } else {
          self.notifications.remove(notification)
        }
      }
    )
  }
}

struct NotificationsView: View {
  @StateObject var model = NotificationsModel()

  var body: some View {
    Toggle("Enable Notifications", isOn: $model.enabled.animation())

    if model.enabled {
      ConfigureNotificationsView(
        notification: .priceDrop,
        enabled: model.enabled(for: .priceDrop)
      )
      ConfigureNotificationsView(
        notification: .newVersion,
        enabled: model.enabled(for: .newVersion)
      )
    }
  }
}

private struct ConfigureNotificationsView: View {
  let notification: ChangeNotification
  @Binding var enabled: Bool

  var body: some View {
    NavigationLink(
      destination: Form {
        Section {
          Toggle("Enable Notifications", isOn: $enabled.animation())
        }
      }
      .navigationBarTitle(notification.title)
    ) {
      HStack {
        Text(notification.title)
        Spacer()
        Text(enabled ? "Enabled" : "Disabled")
          .foregroundColor(.secondary)
      }
    }
  }
}

private extension ChangeNotification {
  var title: String {
    switch self {
    case .newVersion: return "Updates"
    case .priceDrop: return "Price Drops"
    }
  }
}
