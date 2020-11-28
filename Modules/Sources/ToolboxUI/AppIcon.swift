import SwiftUI
import SDWebImageSwiftUI

public struct AppIcon: View {
  let url: URL
  let width: CGFloat

  public init(_ url: URL, width: CGFloat) {
    self.url = url
    self.width = width
  }

  public var body: some View {
    WebImage(url: url)
      .resizable()
      .placeholder {
        Rectangle().foregroundColor(.gray)
      }
      .scaledToFill()
      .clipShape(RoundedRectangle(cornerRadius: width * 0.2237))
      .frame(width: width, height: width, alignment: .center)
  }
}
