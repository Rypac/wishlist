import SwiftUI

extension View {
  public func navigationDestination<Item: Identifiable, Destination: View>(
    item: Binding<Item?>,
    @ViewBuilder destination: @escaping (Item) -> Destination
  ) -> some View {
    navigationDestination(
      isPresented: Binding(
        get: { item.wrappedValue != nil },
        set: { value in
          if !value {
            item.wrappedValue = nil
          }
        }
      ),
      destination: {
        if let item = item.wrappedValue {
          destination(item)
        } else {
          EmptyView()
        }
      }
    )
  }
}
