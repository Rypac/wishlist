import Combine
import Domain
import SwiftUI

struct NewVersionHistoryView: View {
  @State var versions: [Version] = []
  let versionHistory: AnyPublisher<[Version], Never>

  @Environment(\.updateDateFormatter) private var dateFormatter

  var body: some View {
    List(versions, id: \.name) { version in
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
    .onReceive(versionHistory) { versions = $0 }
  }
}
