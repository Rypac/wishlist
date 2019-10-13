import SwiftUI

struct AppListView: View {
  @State private var showAction = false

  @EnvironmentObject var viewModel: AppListViewModel

  var body: some View {
    NavigationView {
      List {
        ForEach(viewModel.apps) { app in
          AppRowView(viewModel: self.viewModel, app: app)
        }
        .onDelete(perform: viewModel.removeApps)
        .onMove(perform: viewModel.moveApps)
      }
      .navigationBarTitle("Wishlist")
      .navigationBarItems(
        leading: Button(action: { self.showAction = true }) {
          Image.slider.imageScale(.large)
        },
        trailing: EditButton()
      )
      .sheet(isPresented: $showAction) {
        SettingsView()
          .environmentObject(self.viewModel.settingsViewModel)
      }
    }
  }
}

private struct AppRowView: View {
  let viewModel: AppListViewModel
  let app: App

  var body: some View {
    NavigationLink(destination: detailsView) {
      VStack(alignment: .leading) {
        Text(app.title)
          .font(.headline)
        Text(app.author)
          .font(.footnote)
          .foregroundColor(.secondary)
      }
      .layoutPriority(1)
      Spacer(minLength: 8)
      Text(app.formattedPrice)
        .lineLimit(1)
        .multilineTextAlignment(.trailing)
        .layoutPriority(1)
    }
  }

  private var detailsView: some View {
    AppDetailsView()
      .environmentObject(viewModel.detailsViewModel(app: app))
  }
}

private extension Image {
  static var slider: Image { Image(systemName: "slider.horizontal.3") }
}
