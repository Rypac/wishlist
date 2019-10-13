import SwiftUI

struct AppListView: View {
  @State private var showSettings = false
  @State private var showShareSheet = false

  @EnvironmentObject var viewModel: AppListViewModel
  @EnvironmentObject var settingsStore: SettingsStore

  var body: some View {
    NavigationView {
      List(viewModel.apps) { app in
        AppRowView(app: app)
//          .contextMenu {
//            Button(action: { self.viewModel.removeApp(app) }) {
//              Text("Delete")
//              Image.trash
//            }
//            Button(action: { self.showShareSheet = true }) {
//              Text("Share")
//              Image.share.padding()
//            }
//          }
          .sheet(isPresented: self.$showShareSheet) {
            ActivityView(showing: self.$showShareSheet, activityItems: [app.url], applicationActivities: nil)
          }
      }
      .navigationBarTitle("Wishlist")
      .navigationBarItems(
        trailing: Button(action: { self.showSettings = true }) {
          Image.slider.imageScale(.large)
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
  let app: App

  var body: some View {
    NavigationLink(destination: AppDetailsView(app: app)) {
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
