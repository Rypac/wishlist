import SwiftUI

public enum SFSymbol: String {
  case sliderHorizontal3 = "slider.horizontal.3"
  case share = "square.and.arrow.up"
}

extension SFSymbol: View {
  public var body: some View {
    Image(systemName: rawValue)
  }
}
