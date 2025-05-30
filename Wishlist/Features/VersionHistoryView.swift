import Combine
import Domain
import Foundation
import SwiftUI

@MainActor
final class VersionHistoryViewModel: ObservableObject {
  struct Environment {
    var versionHistory: AnyPublisher<[Version], Never>
    var system: SystemEnvironment
  }

  @Published private(set) var versions: [Version] = []

  init(environment: Environment) {
    environment.versionHistory
      .map { versions in
        versions.sorted(by: { $0.date > $1.date })
      }
      .assign(to: &$versions)
  }
}

struct VersionHistoryView: View {
  @StateObject var viewModel: VersionHistoryViewModel

  @Environment(\.updateDateFormatter) private var dateFormatter

  var body: some View {
    List(viewModel.versions, id: \.name) { version in
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
    .listStyle(.plain)
    .navigationTitle("Version History")
  }
}
