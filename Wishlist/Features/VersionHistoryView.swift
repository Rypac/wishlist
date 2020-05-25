import ComposableArchitecture
import Foundation
import SwiftUI
import WishlistCore
import WishlistFoundation

struct VersionHistoryState: Equatable {
  var versions: [Version]
}

enum VersionHistoryAction {
  case onAppear
}

struct VersionHistoryEnvironment {}

let versionHistoryReducer = Reducer<VersionHistoryState, VersionHistoryAction, SystemEnvironment<VersionHistoryEnvironment>> { state, action, environment in
  switch action {
  case .onAppear:
    return .none
  }
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
              .fontWeight(.medium)
            Spacer(minLength: 0)
            Text(self.dateFormatter.string(from: version.date))
              .foregroundColor(.secondary)
          }
          if version.notes != nil {
            Text(version.notes!)
              .expandable(initialLineLimit: 3)
          }
        }.padding([.top, .bottom], 4)
      }.navigationBarTitle("Version History")
    }
  }
}
