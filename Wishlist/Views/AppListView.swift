import SwiftUI
import WishlistData

struct AppListView: View {
  @State private var showActionSheet = false

  @EnvironmentObject private var viewModel: AppListViewModel
  @EnvironmentObject private var settingsStore: SettingsStore

  var body: some View {
    NavigationView {
      List {
        ForEach(viewModel.apps, id: \.id, content: AppRow.init)
          .onDelete { indexes in
            self.viewModel.removeApps(at: indexes)
          }
      }
        .navigationBarTitle("Wishlist")
        .navigationBarItems(
          trailing: Button(action: { self.showActionSheet = true }) {
            HStack {
              Image.sort
                .imageScale(.large)
                .accessibility(label: Text("Sort By"))
            }
            .frame(width: 24, height: 24)
          }.hoverEffect()
        )
        .actionSheet(isPresented: $showActionSheet) {
          var buttons = SortOrder.allCases.map { sortOrder in
            Alert.Button.default(Text(sortOrder.title)) {
              self.settingsStore.sortOrder = sortOrder
            }
          }
          buttons.append(.cancel())
          return ActionSheet(title: Text("Sort By"), buttons: buttons)
        }
    }.onDrop(of: [UTI.url], delegate: URLDropDelegate { [viewModel] urls in
      viewModel.addApps(urls: urls)
    })
  }
}

private struct AppRow: View {
  @State private var showShareSheet = false

  let app: App

  var body: some View {
    NavigationLink(destination: AppDetailsView(app: app)) {
      AppRowContent(app: app)
        .onDrag { NSItemProvider(app: self.app) }
        .contextMenu {
          Button(action: {
            let userActivity = NSUserActivity(activityType: ActivityIdentifier.details.rawValue)
            userActivity.userInfo = [ActivityIdentifier.UserInfoKey.id.rawValue: self.app.id]
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: userActivity, options: nil)
          }) {
            Text("Open in New Window")
            Image.window
          }
          Button(action: { self.showShareSheet = true }) {
            Text("Share")
            Image.share
          }
        }
        .sheet(isPresented: self.$showShareSheet) {
          ActivityView(showing: self.$showShareSheet, activityItems: [self.app.url], applicationActivities: nil)
        }
    }
  }
}

private struct AppRowContent: View {
  @Environment(\.updateDateFormatter) private var dateFormatter
  @EnvironmentObject private var settingsStore: SettingsStore

  let app: App

  var body: some View {
    HStack {
      AppIcon(app.icon.medium, width: 50)
      Text(app.title)
        .fontWeight(.medium)
        .layoutPriority(1)
      Spacer()
      Text(detailsContent)
        .lineLimit(1)
        .multilineTextAlignment(.trailing)
        .layoutPriority(1)
    }
  }

  private var detailsContent: String {
    if settingsStore.sortOrder == .updated {
      return dateFormatter.string(from: app.updateDate)
    }
    return app.formattedPrice
  }
}

private extension SortOrder {
  var title: String {
    switch self {
    case .price: return "Price"
    case .title: return "Title"
    case .updated: return "Recently Updated"
    }
  }
}

private extension Image {
  static var sort: Image { Image(systemName: "arrow.up.arrow.down") }
  static var share: Image { Image(systemName: "square.and.arrow.up") }
  static var window: Image { Image(systemName: "square.grid.2x2") }
}
