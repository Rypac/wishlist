import Foundation
import Combine
import Domain
import SwiftUI

struct NewAppListViewEnvironment {
  var apps: AnyPublisher<[AppDetails], Never>
  var versionHistory: (AppDetails.ID) -> AnyPublisher<[Version], Never>
}

struct NewAppListView: View {
  let environment: NewAppListViewEnvironment

  @State private var apps: [AppDetails] = []

  var body: some View {
    List(apps) { app in
      NavigationLink(
        destination: NewAppDetailsContainerView(
          app: app,
          versionHistory: environment.versionHistory(app.id)
        )
      ) {
        AppRowContent(
          title: app.title,
          details: .updated(app.version.date, seen: true),
          icon: app.icon.medium
        )
      }
    }
    .listStyle(PlainListStyle())
    .onReceive(environment.apps) { apps = $0 }
  }
}
