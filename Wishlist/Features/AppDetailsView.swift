import Combine
import Domain
import Foundation
import SwiftUI
import ToolboxUI

struct AppDetailsRepository {
  var app: AnyPublisher<AppDetails?, Never>
  var versionHistory: AnyPublisher<[Version], Never>
  var delete: () async throws -> Void
  var recordViewed: (Date) async throws -> Void
}

@MainActor
final class AppDetailsViewModel: ObservableObject {
  struct Environment {
    var repository: AppDetailsRepository
    var system: SystemEnvironment
  }

  @Published private(set) var app: AppDetails

  let environment: Environment

  init(app: AppDetails, environment: Environment) {
    self.app = app
    self.environment = environment
    environment.repository.app.compactMap { $0 }.assign(to: &$app)
  }

  func recordAppViewed() async {
    let now = environment.system.now()
    try? await environment.repository.recordViewed(now)
  }

  func versionHistoryViewModel() -> VersionHistoryViewModel {
    VersionHistoryViewModel(
      latestVersion: app.version,
      environment: VersionHistoryViewModel.Environment(
        versionHistory: environment.repository.versionHistory,
        system: environment.system
      )
    )
  }
}

struct AppDetailsView: View {
  @StateObject var viewModel: AppDetailsViewModel

  var body: some View {
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: 16) {
        AppHeading(app: viewModel.app)
        Divider()
        AppNotifications()
        if viewModel.app.version.notes != nil {
          Divider()
          AppVersion(version: viewModel.app.version) {
            VersionHistoryView(viewModel: viewModel.versionHistoryViewModel())
          }
        }
        Divider()
        AppDescription(description: viewModel.app.description)
      }
      .padding()
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        ShareAppURLButton(url: viewModel.app.url)
      }
    }
    .navigationTitle("Details")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await viewModel.recordAppViewed()
    }
  }
}

private struct AppHeading: View {
  let title: String
  let seller: String
  let price: String
  let icon: URL
  let url: URL

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      AppIcon(icon, width: 100)
      VStack(alignment: .leading) {
        Text(title)
          .font(.title.bold())
          .fixedSize(horizontal: false, vertical: true)
        Text(seller)
          .font(.headline)
        HStack(alignment: .firstTextBaseline) {
          Text(price)
            .font(.body.monospacedDigit())
          Spacer()
          Link("VIEW", destination: url)
            .font(.subheadline.bold())
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
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

private struct AppDescription: View {
  let description: String

  var body: some View {
    Text("Description")
      .bold()
    Text(description)
      .expandable(initialLineLimit: 3)
  }
}

private final class AppNotificationsViewModel: ObservableObject {
  @Published var notifications: Set<ChangeNotification> = Set()
}

private struct AppNotifications: View {
  @StateObject var viewModel = AppNotificationsViewModel()

  var body: some View {
    Text("Notifications")
      .bold()
    Toggle("Price Drops", isOn: $viewModel.notifications.contains(.priceDrop))
    Toggle("Updates", isOn: $viewModel.notifications.contains(.newVersion))
  }
}

private struct AppVersion<Content: View>: View {
  let version: Version
  @ViewBuilder let content: () -> Content

  @State private var displayVersionHistory: Bool = false

  @Environment(\.updateDateFormatter) private var dateFormatter

  var body: some View {
    VStack(spacing: 8) {
      HStack {
        Text("Release Notes")
          .bold()
        Spacer(minLength: 0)
        Button("Version History") {
          displayVersionHistory = true
        }
        .navigation(isActive: $displayVersionHistory) {
          content()
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

private struct ShareAppURLButton: View {
  let url: URL

  @State private var displayShareSheet: Bool = false

  var body: some View {
    Button {
      displayShareSheet = true
    } label: {
      SFSymbol.share
        .accessibilityLabel("Share")
    }
    .sheet(isPresented: $displayShareSheet) {
      ActivityView(activityItems: [url], applicationActivities: nil)
    }
  }
}
