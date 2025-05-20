import SwiftUI

public struct ExpandableTextModifier: ViewModifier {
  @State private var expanded = false

  public let initialLineLimit: Int
  public let expandedLineLimit: Int?

  public init(initialLineLimit: Int, expandedLineLimit: Int? = nil) {
    self.initialLineLimit = initialLineLimit
    self.expandedLineLimit = expandedLineLimit
  }

  public func body(content: Content) -> some View {
    ZStack(alignment: .bottomTrailing) {
      HStack {
        content
          .lineLimit(expanded ? expandedLineLimit : initialLineLimit)
        Spacer(minLength: 0)
      }
      if !expanded {
        Button("more") {
          expanded.toggle()
        }
        .buttonStyle(.plain)
        .foregroundColor(.blue)
        .padding(.leading, 20)
        .background(
          LinearGradient(
            gradient: Gradient(stops: [
              Gradient.Stop(color: Color(.systemBackground).opacity(0), location: 0),
              Gradient.Stop(color: Color(.systemBackground), location: 0.25),
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
  public func expandable(initialLineLimit: Int, expandedLineLimit: Int? = nil) -> some View {
    modifier(ExpandableTextModifier(initialLineLimit: initialLineLimit, expandedLineLimit: expandedLineLimit))
  }
}
