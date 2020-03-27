import SwiftUI

struct AppListView: View {
  @State private var showActionSheet = false

  @EnvironmentObject private var viewModel: AppListViewModel
  @EnvironmentObject private var settingsStore: SettingsStore

  var body: some View {
    NavigationView {
      List(viewModel.apps, rowContent: AppRow.init)
        .navigationBarTitle("Wishlist")
        .navigationBarItems(
          trailing: Button(action: { self.showActionSheet = true }) {
            HStack {
              Image.sort
                .imageScale(.large)
                .accessibility(label: Text("Sort By"))
            }
            .frame(width: 24, height: 24)
          }
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
    }
  }
}

private struct AppRow: View {
  @State private var showShareSheet = false

  let app: App

  var body: some View {
    NavigationLink(destination: AppDetailsView(app: app)) {
      AppRowContent(app: app)
        .contextMenu {
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
  let app: App

  var body: some View {
    HStack {
      AppIcon(app.iconURL, width: 50)
      Text(app.title)
        .layoutPriority(1)
      Spacer()
      Text(app.formattedPrice)
        .lineLimit(1)
        .multilineTextAlignment(.trailing)
        .layoutPriority(1)
    }
  }
}

private extension SortOrder {
  var title: String {
    switch self {
    case .price: return "Price"
    case .title: return "Title"
    }
  }
}

private extension Image {
  static var sort: Image { Image(systemName: "arrow.up.arrow.down") }
  static var share: Image { Image(systemName: "square.and.arrow.up") }
}
