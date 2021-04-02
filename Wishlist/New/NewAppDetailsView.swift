import Combine
import Domain
import SwiftUI
import ToolboxUI

struct NewAppDetailsContainerView: View {
  let app: AppDetails
  let versionHistory: AnyPublisher<[Version], Never>

  @State private var showShareSheet = false

  var body: some View {
    NewAppDetailsView(app: app, versionHistory: versionHistory)
      .navigationBarTitle("Details", displayMode: .inline)
      .navigationBarItems(
        trailing: Button(action: { showShareSheet = true }) {
          SFSymbol.share
            .imageScale(.large)
            .accessibility(label: Text("Share"))
            .frame(width: 24, height: 24)
        }
        .hoverEffect()
      )
      .sheet(isPresented: $showShareSheet) {
        ActivityView(showing: $showShareSheet, activityItems: [app.url], applicationActivities: nil)
      }
  }
}

struct NewAppDetailsView: View {
  let app: AppDetails
  let versionHistory: AnyPublisher<[Version], Never>

  var body: some View {
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: 16) {
        AppHeading(app: app)
        Divider()
        AppNotifications(notifications: app.notifications)
        if app.version.notes != nil {
          Divider()
          AppVersion(version: app.version, versionHistory: versionHistory)
        }
        Divider()
        AppDescription(description: app.description)
      }
      .padding()
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
  let notifications: Set<ChangeNotification>

  var body: some View {
    Text("Notifications")
      .bold()
    Toggle("Price Drops", isOn: .constant(notifications.contains(.priceDrop)))
    Toggle("Updates", isOn: .constant(notifications.contains(.newVersion)))
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
          destination: NewVersionHistoryView(versions: [version], versionHistory: versionHistory)
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
