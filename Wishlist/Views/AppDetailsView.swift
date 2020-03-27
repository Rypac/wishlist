import SwiftUI

struct AppDetailsView: View {
  @State private var showShareSheet = false

  let app: App

  var body: some View {
    ScrollView(.vertical) {
      HStack {
        VStack(alignment: .leading, spacing: 16) {
          AppHeading(app: app)
          ReleaseNotes(app: app)
          AppDescription(app: app)
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
        Text(app.seller)
          .font(.headline)
      }
    }
  }
}

private struct AppDescription: View {
  let app: App

  var body: some View {
    Group {
      Divider()
      Text("Description")
        .bold()
      Text(app.description)
    }
  }
}

private struct ReleaseNotes: View {
  @Environment(\.updateDateFormatter) private var dateFormatter

  let app: App

  var body: some View {
    guard let releaseNotes = app.releaseNotes else {
      return AnyView(EmptyView())
    }
    return AnyView(
      Group {
        Divider()
        HStack {
          Text("Release Notes")
            .bold()
            .layoutPriority(2)
          Spacer()
          Text("Updated: \(dateFormatter.string(from: app.updateDate))")
            .multilineTextAlignment(.trailing)
            .layoutPriority(1)
        }
        Text(releaseNotes)
      }
    )
  }
}

private extension Image {
  static var share: Image { Image(systemName: "square.and.arrow.up") }
}
