import SwiftUI

public struct AppIcon: View {
  let url: URL
  let width: CGFloat

  public init(_ url: URL, width: CGFloat) {
    self.url = url
    self.width = width
  }

  public var body: some View {
    AsyncImage(url: url) { image in
      image.resizable()
    } placeholder: {
      Color.gray
    }
    .scaledToFill()
    .frame(width: width, height: width, alignment: .center)
    .clipShape(RoundedRectangle(cornerRadius: width * 0.2237))
    .shadow(radius: 0.5)
  }
}
