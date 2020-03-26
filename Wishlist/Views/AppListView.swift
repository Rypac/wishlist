import SwiftUI
import URLImage

struct AppListView: View {
  @State private var showSettings = false

  @EnvironmentObject var viewModel: AppListViewModel
  @EnvironmentObject var settingsStore: SettingsStore

  var body: some View {
    NavigationView {
      List(viewModel.apps) { app in
        AppRowView(viewModel: self.viewModel, app: app)
      }
      .navigationBarTitle("Wishlist")
      .navigationBarItems(
        trailing: Button(action: { self.showSettings = true }) {
          HStack {
            Image.slider
              .imageScale(.large)
              .accessibility(label: Text("Settings"))
          }
          .frame(width: 24, height: 24)
        }
      )
      .sheet(isPresented: $showSettings) {
        SettingsView()
          .environmentObject(self.settingsStore)
      }
    }
  }
}

private struct AppRowView: View {
  let viewModel: AppListViewModel
  let app: App

  @State var showShareSheet = false

  var body: some View {
    NavigationLink(destination: AppDetailsView(app: app)) {
      AppRowContentView(app: app)
        .contextMenu {
          Button(action: { self.viewModel.removeApp(self.app) }) {
            Text("Delete")
            Image.trash.imageScale(.small)
          }.foregroundColor(.red)
          Button(action: { self.showShareSheet = true }) {
            Text("Share")
            Image.share.imageScale(.small)
          }
        }
        .sheet(isPresented: self.$showShareSheet) {
          ActivityView(showing: self.$showShareSheet, activityItems: [self.app.url], applicationActivities: nil)
        }
    }
  }
}

private struct AppRowContentView: View {
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

private extension Image {
  static var share: Image { Image(systemName: "square.and.arrow.up") }
  static var trash: Image { Image(systemName: "trash") }
  static var slider: Image { Image(systemName: "slider.horizontal.3") }
}
