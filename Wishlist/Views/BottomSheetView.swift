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
          Button(action: { self.isPresented.toggle() }) {
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
        .zIndex(1)
      if isPresented.wrappedValue {
        Color.black
          .opacity(0.5)
          .transition(.opacity)
          .edgesIgnoringSafeArea(.all)
          .onTapGesture {
            isPresented.wrappedValue.toggle()
          }
          .zIndex(2)
        BottomSheetView(isPresented: isPresented, content: content)
          .transition(.move(edge: .bottom))
          .zIndex(3)
      }
    }
  }
}
