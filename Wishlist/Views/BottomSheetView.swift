import SwiftUI

struct BottomSheetView<Content: View>: View {
  @Binding var isPresented: Bool
  @State private var childSize: CGSize = .zero

  let content: () -> Content

  init(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
    self._isPresented = isPresented
    self.content = content
  }

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        HStack {
          Spacer()
          Button(action: { withAnimation { self.isPresented.toggle() } }) {
            Image(systemName: "xmark.circle.fill")
              .padding()
          }.hoverEffect()
        }
        self.content()
      }
      .modifier(ChildSizeModifier(size: self.$childSize))
      .frame(width: geometry.size.width, height: min(geometry.size.height, self.childSize.height), alignment: .top)
      .background(Color(.secondarySystemBackground))
      .cornerRadius(16)
      .frame(height: geometry.size.height, alignment: .bottom)
      .transition(.slide)
      .animation(.interactiveSpring())
    }
  }
}

private struct ChildSizeModifier: ViewModifier {
  struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value _: inout CGSize, nextValue: () -> Value) {
      _ = nextValue()
    }
  }

  @Binding var size: CGSize

  func body(content: Content) -> some View {
    content
      .background(
        GeometryReader { proxy in
          Color.clear
            .preference(key: SizePreferenceKey.self, value: proxy.size)
        }
      )
      .onPreferenceChange(SizePreferenceKey.self) { preferences in
        self.size = preferences
      }
  }
}

extension View {
  func bottomSheet<Content: View>(
    isPresented: Binding<Bool>,
    @ViewBuilder content: @escaping () -> Content
  ) -> some View {
    ZStack {
      self
      if isPresented.wrappedValue {
        Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
        BottomSheetView(isPresented: isPresented, content: content)
      }
    }
  }
}
