import Combine
import Domain
import Foundation
import SwiftUI
import ToolboxUI

final class AppDetailsViewModel: ObservableObject {
  struct Environment {
    var versionHistory: AnyPublisher<[Version], Never>
  }

  @Published private(set) var app: AppDetails

  let environment: Environment

  init(app: AppDetails, environment: Environment) {
    self.app = app
    self.environment = environment
  }

  var notifications: Binding<Set<ChangeNotification>> {
    Binding(
      get: { self.app.notifications },
      set: { self.app.notifications = $0 }
    )
  }
}

struct NewAppDetailsView: View {
  @StateObject var viewModel: AppDetailsViewModel

  var body: some View {
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: 16) {
        AppHeading(app: viewModel.app)
        Divider()
        AppNotifications(notifications: viewModel.notifications)
        if viewModel.app.version.notes != nil {
          Divider()
          AppVersion(version: viewModel.app.version, versionHistory: viewModel.environment.versionHistory)
        }
        Divider()
        AppDescription(description: viewModel.app.description)
      }
      .padding()
    }
    .navigationBarTitle("Details", displayMode: .inline)
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

private extension Binding {
  func contains<Element>(_ element: Element) -> Binding<Bool> where Value == Set<Element> {
    Binding<Bool>(
      get: { wrappedValue.contains(element) },
      set: { newValue in
        if newValue {
          wrappedValue.insert(element)
        } else {
          wrappedValue.remove(element)
        }
      }
    )
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
          destination: NewVersionHistoryView(
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
