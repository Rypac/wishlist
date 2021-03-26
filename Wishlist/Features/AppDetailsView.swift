import Combine
import ComposableArchitecture
import SwiftUI
import Domain
import ToolboxUI

struct AppDetailsState: Equatable {
  var app: AppDetails
  var versions: [Version]?
  var showVersionHistory: Bool
}

enum AppDetailsAction {
  case openInAppStore(URL)
  case showVersionHistory(Bool)
  case notification(ChangeNotification, enable: Bool)
  case versionHistory(VersionHistoryAction)
}

struct AppDetailsEnvironment {
  var openURL: (URL) -> Void
  var versionHistory: (AppID) throws -> [Version]
  var saveNotifications: (AppID, Set<ChangeNotification>) throws -> Void
}

let appDetailsReducer = Reducer<AppDetailsState, AppDetailsAction, SystemEnvironment<AppDetailsEnvironment>>.combine(
  versionHistoryReducer.pullback(
    state: \.versionHistoryState,
    action: /AppDetailsAction.versionHistory,
    environment: { systemEnvironment in
      systemEnvironment.map { _ in
        VersionHistoryEnvironment()
      }
    }
  ),
  Reducer { state, action, environment in
    switch action {
    case let .showVersionHistory(show):
      state.showVersionHistory = show
      if show, state.versions == nil {
        state.versions = try? environment.versionHistory(state.app.id)
      }
      return .none

    case let .notification(notification, enable):
      if enable {
        state.app.notifications.insert(notification)
      } else {
        state.app.notifications.remove(notification)
      }
      let id = state.app.id
      let notifications = state.app.notifications
      return .fireAndForget {
        try? environment.saveNotifications(id, notifications)
      }

    case let .openInAppStore(url):
      return .fireAndForget {
        environment.openURL(url)
      }

    case .versionHistory:
      return .none
    }
  }
)

struct ConnectedAppDetailsView: View {
  var store: Store<AppDetailsState, AppDetailsAction>

  @State private var showShareSheet = false

  var body: some View {
    WithViewStore(store.scope(state: \.app.url)) { viewStore in
      AppDetailsContentView(store: store)
        .navigationBarTitle("Details", displayMode: .inline)
        .navigationBarItems(
          trailing: Button(action: { showShareSheet = true }) {
            Image.share
              .imageScale(.large)
              .frame(width: 24, height: 24)
          }.hoverEffect()
        )
        .sheet(isPresented: $showShareSheet) {
          ActivityView(showing: $showShareSheet, activityItems: [viewStore.state], applicationActivities: nil)
        }
    }
  }
}

private extension AppDetailsState {
  var versionHistoryState: VersionHistoryState {
    get { VersionHistoryState(versions: versions ?? []) }
    set { versions = newValue.versions }
  }

  var headingState: AppHeading.ViewState {
    .init(
      title: app.title,
      seller: app.seller,
      price: app.price.current.formatted,
      icon: app.icon.large,
      url: app.url
    )
  }
}

struct AppDetailsContentView: View {
  let store: Store<AppDetailsState, AppDetailsAction>

  var body: some View {
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: 16) {
        AppHeading(store: store.scope(state: \.headingState))
        AppNotifications(store: store.scope(state: \.app.notifications))
        ReleaseNotes(store: store)
        WithViewStore(store.scope(state: \.app.description)) { viewStore in
          AppDescription(description: viewStore.state)
        }
      }
      .padding()
    }
  }
}

private struct AppHeading: View {
  struct ViewState: Equatable {
    let title: String
    let seller: String
    let price: String
    let icon: URL
    let url: URL
  }

  let store: Store<ViewState, AppDetailsAction>

  var body: some View {
    WithViewStore(store) { viewStore in
      HStack(alignment: .top, spacing: 16) {
        AppIcon(viewStore.icon, width: 100)
        VStack(alignment: .leading) {
          Text(viewStore.title)
            .font(Font.title.bold())
            .fixedSize(horizontal: false, vertical: true)
          Text(viewStore.seller)
            .font(.headline)
          HStack {
            Text(viewStore.price)
            Spacer()
            ViewInAppStoreButton {
              viewStore.send(.openInAppStore(viewStore.url))
            }
          }.padding(.top, 8)
        }
      }
    }
  }
}

private struct ViewInAppStoreButton: View {
  let action: () -> Void

  init(_ action: @escaping () -> Void) {
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      Text("VIEW")
        .font(.subheadline)
        .fontWeight(.bold)
        .foregroundColor(.white)
        .padding([.leading, .trailing], 20)
        .padding([.top, .bottom], 8)
        .background(Capsule().fill(Color.blue))
    }.hoverEffect(.lift)
  }
}

private struct AppNotifications: View {
  let store: Store<Set<ChangeNotification>, AppDetailsAction>

  var body: some View {
    Group {
      Divider()
      Text("Notifications")
        .bold()
      WithViewStore(store.scope(state: { $0.contains(.priceDrop) })) { viewStore in
        Toggle(isOn: viewStore.binding(send: { .notification(.priceDrop, enable: $0) })) {
          Text("Price Drops")
        }
      }
      WithViewStore(store.scope(state: { $0.contains(.newVersion) })) { viewStore in
        Toggle(isOn: viewStore.binding(send: { .notification(.newVersion, enable: $0) })) {
          Text("Updates")
        }
      }
    }
  }
}

private struct AppDescription: View {
  let description: String

  var body: some View {
    Group {
      Divider()
      Text("Description")
        .bold()
      Text(description)
        .expandable(initialLineLimit: 3)
    }
  }
}

private extension AppDetailsState {
  var releaseNotesViewState: ReleaseNotes.ViewState {
    .init(showHistory: showVersionHistory, version: app.version)
  }
}

private struct ReleaseNotes: View {
  struct ViewState: Equatable {
    let showHistory: Bool
    let version: Version
  }

  @Environment(\.updateDateFormatter) private var dateFormatter

  let store: Store<AppDetailsState, AppDetailsAction>

  var body: some View {
    WithViewStore(store.scope(state: \.releaseNotesViewState)) { viewStore in
      if let versionNotes = viewStore.version.notes {
        Divider()
        VStack(spacing: 8) {
          HStack {
            Text("Release Notes")
              .bold()
            Spacer(minLength: 0)
            NavigationLink(
              destination: VersionHistoryView(
                store: store.scope(
                  state: \.versionHistoryState,
                  action: AppDetailsAction.versionHistory
                )
              ),
              isActive: viewStore.binding(get: \.showHistory, send: AppDetailsAction.showVersionHistory)
            ) {
              Text("Version History")
            }
          }
          HStack {
            Text(viewStore.version.name)
              .font(.callout)
              .foregroundColor(.secondary)
            Spacer(minLength: 0)
            Text(dateFormatter.string(from: viewStore.version.date))
              .font(.callout)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.trailing)
          }
        }
        Text(versionNotes)
          .expandable(initialLineLimit: 3)
      }
    }
  }
}

private extension Image {
  static var share: Image { Image(systemName: "square.and.arrow.up") }
}
