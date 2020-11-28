import ComposableArchitecture
import SwiftUI
import Domain

struct NotificationState: Equatable {
  var enabled: Bool
  var notifyOnChange: Set<ChangeNotification>
}

enum NotificationAction {
  case enable(Bool)
  case notifiy(ChangeNotification, enabled: Bool)
}

struct SettingsState: Equatable {
  var theme: Theme
  var notifications: NotificationState
}

enum SettingsAction {
  case setTheme(Theme)
  case viewLicense(URL)
  case notifications(NotificationAction)
  case viewSourceCode
  case deleteAll
}

struct SettingsEnvironment {
  var saveTheme: (Theme) -> Void
  var openURL: (URL) -> Void
}

let settingsReducer = Reducer<SettingsState, SettingsAction, SettingsEnvironment> { state, action, environment in
  switch action {
  case let .setTheme(theme):
    state.theme = theme
    return .fireAndForget {
      environment.saveTheme(theme)
    }

  case let .viewLicense(url):
    return .fireAndForget {
      environment.openURL(url)
    }

  case .viewSourceCode:
    return .fireAndForget {
      environment.openURL(URL(string: "https://github.com/Rypac/wishlist")!)
    }

  case let .notifications(.enable(enabled)):
    state.notifications.enabled = enabled
    return .none

  case let .notifications(.notifiy(notification, enabled)):
    if enabled {
      state.notifications.notifyOnChange.insert(notification)
    } else {
      state.notifications.notifyOnChange.remove(notification)
    }
    return .none

  case .deleteAll:
    return .none
  }
}

struct SettingsView: View {
  let store: Store<SettingsState, SettingsAction>

  @Environment(\.presentationMode) var presentationMode

  var body: some View {
    WithViewStore(store) { viewStore in
      NavigationView {
        Form {
          Section(header: Text("Appearance")) {
            Picker(
              "Theme",
              selection: viewStore.binding(get: \.theme, send: SettingsAction.setTheme)
            ) {
              ForEach(Theme.allCases, id: \.self) { theme in
                Text(theme.title).tag(theme)
              }
            }.pickerStyle(SegmentedPickerStyle())
          }
          Section(header: Text("Notifications")) {
            NotificationView(
              store: store.scope(state: \.notifications, action: SettingsAction.notifications)
            )
          }
          Section(header: Text("About")) {
            NavigationLink(
              "Acknowledgements",
              destination: LicensesView(viewLicense: { viewStore.send(.viewLicense($0)) })
            )
            Button("Source Code") {
              viewStore.send(.viewSourceCode)
            }
          }
          Section(
            header: Text("Danger Zone"),
            footer: Text("This will remove all apps from your Wishlist and cannot be undone.")
          ) {
            Button("Delete All") {
              viewStore.send(.deleteAll)
            }.foregroundColor(.red)
          }
        }
        .navigationBarTitle("Settings")
        .navigationBarItems(trailing: Button("Close") {
          presentationMode.wrappedValue.dismiss()
        })
      }.navigationViewStyle(StackNavigationViewStyle())
    }
  }
}

private struct NotificationView: View {
  let store: Store<NotificationState, NotificationAction>

  var body: some View {
    WithViewStore(store) { viewStore in
      Group {
        Toggle(
          "Enable Notifications",
          isOn: viewStore.binding(get: \.enabled, send: NotificationAction.enable)
        )
        if viewStore.enabled {
          EnableNotificationsView(
            store: store.scope(
              state: {
                .init(notification: .priceDrop, enabled: $0.notifyOnChange.contains(.priceDrop))
              }
            )
          )
          EnableNotificationsView(
            store: store.scope(
              state: {
                .init(notification: .newVersion, enabled: $0.notifyOnChange.contains(.newVersion))
              }
            )
          )
        }
      }
    }
  }
}

private struct EnableNotificationsView: View {
  struct ViewState: Equatable {
    var notification: ChangeNotification
    var enabled: Bool
  }

  var store: Store<ViewState, NotificationAction>

  var body: some View {
    WithViewStore(store) { viewStore in
      NavigationLink(
        destination: Form {
          Section(header: Text("")) {
            Toggle(
              "Enable Notifications",
              isOn: viewStore.binding(
                get: \.enabled,
                send: { .notifiy(viewStore.notification, enabled: $0) }
              )
            )
          }
        }.navigationBarTitle(viewStore.title)
      ) {
        HStack {
          Text(viewStore.title)
          Spacer()
          Text(viewStore.enabled ? "Enabled" : "Disabled")
            .foregroundColor(.secondary)
        }
      }
    }
  }
}

private extension EnableNotificationsView.ViewState {
  var title: String {
    switch notification {
    case .newVersion: return "Updates"
    case .priceDrop: return "Price Drops"
    }
  }
}

private struct LicensesView: View {
  private struct License {
    let title: String
    let terms: String
    let url: URL
  }

  private let licenses = [
    License(
      title: "Composable Architecture",
      terms: mit(copyright: "2020 Point-Free, Inc."),
      url: URL(string: "https://github.com/pointfreeco/swift-composable-architecture")!
    ),
    License(
      title: "SDWebImage",
      terms: mit(copyright: "2009-2018 Olivier Poitrey rs@dailymotion.com"),
      url: URL(string: "https://github.com/SDWebImage/SDWebImage")!
    )
  ]

  let viewLicense: (URL) -> Void

  var body: some View {
    List(licenses, id: \.title) { license in
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Text(license.title)
            .bold()
          Button(license.url.absoluteString) {
            viewLicense(license.url)
          }
            .font(.callout)
            .buttonStyle(PlainButtonStyle())
            .foregroundColor(.blue)
        }
        Text(license.terms)
          .font(.system(.footnote, design: .monospaced))
      }
      .padding([.top, .bottom], 8)
    }
    .navigationBarTitle("Acknowledgements")
  }
}

private extension Theme {
  var title: String {
    switch self {
    case .system: return "System"
    case .light: return "Light"
    case .dark: return "Dark"
    }
  }
}

private func mit(copyright: String) -> String {
  """
  MIT License

  Copyright (c) \(copyright)

  Permission is hereby granted, free of charge, to any person obtaining a copy \
  of this software and associated documentation files (the "Software"), to deal \
  in the Software without restriction, including without limitation the rights \
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
  copies of the Software, and to permit persons to whom the Software is furnished \
  to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all \
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR \
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, \
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE \
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER \
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, \
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN \
  THE SOFTWARE.
  """
}
