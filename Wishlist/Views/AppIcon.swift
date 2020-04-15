import SwiftUI
import SDWebImageSwiftUI

struct AppIcon: View {
  let url: URL
  let width: CGFloat

  init(_ url: URL, width: CGFloat) {
    self.url = url
    self.width = width
  }

  var body: some View {
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
