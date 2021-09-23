import SwiftUI

extension View {
  public func navigation<Destination: View>(
    isActive: Binding<Bool>,
    @ViewBuilder destination: @escaping () -> Destination
  ) -> some View {
    background {
      NavigationLink(isActive: isActive, destination: destination, label: EmptyView.init)
    }
  }

  public func navigation<Item: Identifiable, Destination: View>(
    item: Binding<Item?>,
    @ViewBuilder destination: @escaping (Item) -> Destination
  ) -> some View {
    background {
      NavigationLink(
        isActive: Binding(
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
        },
        label: EmptyView.init
      )
    }
  }
}
