import SwiftUI

struct AppDetailsView: View {
  @State private var showShareSheet = false

  @EnvironmentObject var viewModel: AppDetailsViewModel

  var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading) {
          Text(viewModel.title)
            .font(.title)
            .fixedSize(horizontal: false, vertical: true)
          Text(viewModel.author)
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
        }
        Text(viewModel.description)
          .font(.body)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding()
    }
    .navigationBarTitle(Text("Details"), displayMode: .inline)
    .navigationBarItems(
      trailing: Button(action: { self.showShareSheet = true }, label: { Image.share })
    )
    .sheet(isPresented: $showShareSheet, content: {
      ActivityView(showing: self.$showShareSheet, activityItems: [self.viewModel.url], applicationActivities: nil)
    })
  }
}

private extension Image {
  static var share: Image { Image(systemName: "square.and.arrow.up") }
}
