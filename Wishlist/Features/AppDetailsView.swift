import Combine
import Domain
import Foundation
import SwiftUI
import ToolboxUI

struct AppDetailsRepository {
  var app: AnyPublisher<AppDetails?, Never>
  var versionHistory: AnyPublisher<[Version], Never>
  var delete: () throws -> Void
  var recordViewed: (Date) throws -> Void
}

final class AppDetailsViewModel: ObservableObject {
  struct Environment {
    var repository: AppDetailsRepository
    var system: SystemEnvironment<Void>
  }

  @Published private(set) var app: AppDetails
  @Published var notifications: Set<ChangeNotification> = Set()

  let environment: Environment

  init(app: AppDetails, environment: Environment) {
    self.app = app
    self.environment = environment
    environment.repository.app.compactMap { $0 }.assign(to: &$app)
  }

  func onAppear() {
    let now = environment.system.now()
    try? environment.repository.recordViewed(now)
  }
}

struct AppDetailsView: View {
  @StateObject var viewModel: AppDetailsViewModel

  var body: some View {
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: 16) {
        AppHeading(app: viewModel.app)
        Divider()
        AppNotifications(notifications: $viewModel.notifications)
        if viewModel.app.version.notes != nil {
          Divider()
          AppVersion(
            version: viewModel.app.version,
            versionHistory: viewModel.environment.repository.versionHistory
          )
        }
        Divider()
        AppDescription(description: viewModel.app.description)
      }
      .padding()
    }
    .navigationBarTitle("Details", displayMode: .inline)
    .onAppear {
      viewModel.onAppear()
    }
  }
}

private struct AppHeading: View {
  let title: String
  let seller: String
  let price: String
  let icon: URL
  let url: URL

  @Environment(\.openURL) private var openURL

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      AppIcon(icon, width: 100)
      VStack(alignment: .leading) {
        Text(title)
          .font(Font.title.bold())
          .fixedSize(horizontal: false, vertical: true)
        Text(seller)
          .font(.headline)
        HStack {
          Text(price)
          Spacer()
          ViewInAppStoreButton {
            openURL(url)
          }
        }
        .padding(.top, 8)
      }
    }
  }
}

private extension AppHeading {
  init(app: AppDetails) {
    title = app.title
    seller = app.seller
    price = app.price.current.formatted
    icon = app.icon.large
    url = app.url
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
    }
    .hoverEffect(.lift)
  }
}

private struct AppDescription: View {
  let description: String

  var body: some View {
    Text("Description")
      .bold()
    Text(description)
      .expandable(initialLineLimit: 3)
  }
}

private struct AppNotifications: View {
  @Binding var notifications: Set<ChangeNotification>

  var body: some View {
    Text("Notifications")
      .bold()
    Toggle("Price Drops", isOn: $notifications.contains(.priceDrop))
    Toggle("Updates", isOn: $notifications.contains(.newVersion))
  }
}

private struct AppVersion: View {
  let version: Version
  let versionHistory: AnyPublisher<[Version], Never>

  @Environment(\.updateDateFormatter) private var dateFormatter

  var body: some View {
    VStack(spacing: 8) {
      HStack {
        Text("Release Notes")
          .bold()
        Spacer(minLength: 0)
        NavigationLink(
          destination: VersionHistoryView(
            viewModel: VersionHistoryViewModel(latestVersion: version, versionHistory: versionHistory)
          )
        ) {
          Text("Version History")
        }
      }
      HStack {
        Text(version.name)
          .font(.callout)
          .foregroundColor(.secondary)
        Spacer(minLength: 0)
        Text(dateFormatter.string(from: version.date))
          .font(.callout)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.trailing)
      }
    }
    if let releaseNotes = version.notes {
      Text(releaseNotes)
        .expandable(initialLineLimit: 3)
    }
  }
}
