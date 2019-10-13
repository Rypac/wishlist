import SwiftUI

struct AppDetailsView: View {
  @State private var showShareSheet = false

  let app: App

  var body: some View {
    ScrollView(.vertical) {
      HStack {
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading) {
            Text(app.title)
              .font(.title)
            Text(app.author)
              .font(.headline)
          }
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

private extension Image {
  static var share: Image { Image(systemName: "square.and.arrow.up") }
}
