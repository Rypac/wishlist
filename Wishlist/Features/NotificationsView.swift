import Combine
import Domain
import Foundation
import SwiftUI

final class NotificationsModel: ObservableObject {
  @Published var enabled = false
  @Published var notifications = Set<ChangeNotification>()
}

struct NotificationsView: View {
  @StateObject var model = NotificationsModel()

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
    case .newVersion: return "Updates"
    case .priceDrop: return "Price Drops"
    }
  }
}
