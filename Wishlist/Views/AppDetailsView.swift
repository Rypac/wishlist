import SwiftUI

struct AppDetailsView: View {
  @State private var showShareSheet = false

  @EnvironmentObject var viewModel: AppDetailsViewModel

  var body: some View {
    ScrollView(.vertical) {
      HStack {
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading) {
            Text(viewModel.title)
              .font(.title)
            Text(viewModel.author)
              .font(.headline)
          }
          Text(viewModel.description)
            .font(.body)
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
    .sheet(isPresented: $showShareSheet, content: {
      ActivityView(showing: self.$showShareSheet, activityItems: [self.viewModel.url], applicationActivities: nil)
    })
  }
}

private extension Image {
  static var share: Image { Image(systemName: "square.and.arrow.up") }
}
