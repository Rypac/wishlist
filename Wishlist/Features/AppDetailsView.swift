import ComposableArchitecture
import SwiftUI
import WishlistData

struct AppDetailsState: Equatable {
  var app: App
}

enum AppDetailsAction {
  case openInAppStore(URL)
}

struct AppDetailsEnvironment {
  var openURL: (URL) -> Void
}

let appDetailsReducer = Reducer<AppDetailsState, AppDetailsAction, AppDetailsEnvironment>.strict { state, action in
  switch action {
  case let .openInAppStore(url):
    return { environment in
      .fireAndForget {
        environment.openURL(url)
      }
    }
  }
}

struct ConnectedAppDetailsView: View {
  var store: Store<AppDetailsState, AppDetailsAction>

  var body: some View {
    WithViewStore(store) { viewStore in
      AppDetailsView(app: viewStore.app)
    }
  }
}

struct AppDetailsView: View {
  @State private var showShareSheet = false

  let app: App

  var body: some View {
    AppDetailsContentView(app: app)
      .navigationBarTitle("Details", displayMode: .inline)
      .navigationBarItems(
        trailing: Button(action: { self.showShareSheet = true }) {
          Image.share.imageScale(.large)
        }.hoverEffect()
      )
      .sheet(isPresented: $showShareSheet) {
        ActivityView(showing: self.$showShareSheet, activityItems: [self.app.url], applicationActivities: nil)
      }
  }
}

struct AppDetailsContentView: View {
  let app: App

  var body: some View {
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: 16) {
        AppHeading(app: app)
        ReleaseNotes(app: app)
        AppDescription(app: app)
      }
      .padding()
    }
  }
}

private struct AppHeading: View {
  let app: App

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      AppIcon(app.icon.large, width: 100)
      VStack(alignment: .leading) {
        Text(app.title)
          .font(Font.title.bold())
          .fixedSize(horizontal: false, vertical: true)
        Text(app.seller)
          .font(.headline)
        HStack {
          Text(app.price.formatted)
          Spacer()
          ViewInAppStoreButton(url: app.url)
        }.padding(.top, 8)
      }
    }
  }
}

private struct ViewInAppStoreButton: View {
  let url: URL

  var body: some View {
    Button(action: { UIApplication.shared.open(self.url) }) {
      Text("VIEW")
        .font(.subheadline)
        .fontWeight(.bold)
        .foregroundColor(.white)
        .padding([.leading, .trailing], 20)
        .padding([.top, .bottom], 6)
        .background(Color.blue)
        .cornerRadius(.infinity)
    }.hoverEffect()
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
        .expandable(initialLineLimit: 3)
    }
  }
}

private struct ReleaseNotes: View {
  @Environment(\.updateDateFormatter) private var dateFormatter

  let app: App

  var body: some View {
    Group {
      if app.releaseNotes != nil {
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
        Text(app.releaseNotes!)
          .expandable(initialLineLimit: 3)
      } else {
        EmptyView()
      }
    }
  }
}

struct ExpandableTextModifier: ViewModifier {
  @State private var expanded = false

  let initialLineLimit: Int
  let expandedLineLimit: Int?

  init(initialLineLimit: Int, expandedLineLimit: Int? = nil) {
    self.initialLineLimit = initialLineLimit
    self.expandedLineLimit = expandedLineLimit
  }

  func body(content: Content) -> some View {
    ZStack(alignment: .bottomTrailing) {
      HStack {
        content
          .lineLimit(expanded ? expandedLineLimit : initialLineLimit)
        Spacer(minLength: 0)
      }
      if !expanded {
        Button("more") {
          self.expanded.toggle()
        }
          .padding(.leading, 20)
          .background(
            LinearGradient(
              gradient: Gradient(stops: [
                Gradient.Stop(color: Color(.systemBackground).opacity(0), location: 0),
                Gradient.Stop(color: Color(.systemBackground), location: 0.25)
              ]),
              startPoint: .leading,
              endPoint: .trailing
            )
          )
      }
    }
  }
}

extension View {
  func expandable(initialLineLimit: Int, expandedLineLimit: Int? = nil) -> some View {
    modifier(ExpandableTextModifier(initialLineLimit: initialLineLimit, expandedLineLimit: expandedLineLimit))
  }
}

private extension Image {
  static var share: Image { Image(systemName: "square.and.arrow.up") }
}
