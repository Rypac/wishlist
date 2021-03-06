import ComposableArchitecture
import Foundation
import SwiftUI
import Domain

struct VersionHistoryState: Equatable {
  var versions: [Version]
}

enum VersionHistoryAction {
  case never
}

struct VersionHistoryEnvironment {}

let versionHistoryReducer = Reducer<VersionHistoryState, VersionHistoryAction, SystemEnvironment<VersionHistoryEnvironment>> { state, action, environment in
  .none
}

struct VersionHistoryView: View {
  let store: Store<VersionHistoryState, VersionHistoryAction>

  @Environment(\.updateDateFormatter) private var dateFormatter

  var body: some View {
    WithViewStore(store.scope(state: \.versions)) { viewStore in
      List(viewStore.state, id: \.date) { version in
        VStack(spacing: 8) {
          HStack {
            Text(version.name)
              .font(.callout)
              .bold()
            Spacer()
            Text(dateFormatter.string(from: version.date))
              .font(.callout)
              .foregroundColor(.secondary)
          }
          if let notes = version.notes {
            Text(notes)
              .expandable(initialLineLimit: 3)
          }
        }
        .padding(.vertical, 8)
      }
      .navigationBarTitle("Version History")
    }
  }
}
