import SwiftUI

struct AppDetailsView: View {
  @State private var showShareSheet = false

  let app: App

  var body: some View {
    ScrollView(.vertical) {
      HStack {
        VStack(alignment: .leading, spacing: 16) {
          AppHeading(app: app)
          Text(app.description)
        }
        .layoutPriority(1)
        Spacer()
      }
      .padding()
    }
    .navigationBarTitle("Details", displayMode: .inline)
    .navigationBarItems(
      trailing: Button(action: { self.showShareSheet = true }) {
        Image.share.imageScale(.large)
      }
    )
    .sheet(isPresented: $showShareSheet) {
      ActivityView(showing: self.$showShareSheet, activityItems: [self.app.url], applicationActivities: nil)
    }
  }
}

private struct AppHeading: View {
  let app: App

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      AppIcon(app.iconURL, width: 100)
      VStack(alignment: .leading) {
        Text(app.title)
          .font(Font.title.bold())
        Text(app.author)
          .font(.headline)
      }
    }
  }
}

private extension Image {
  static var share: Image { Image(systemName: "square.and.arrow.up") }
}
