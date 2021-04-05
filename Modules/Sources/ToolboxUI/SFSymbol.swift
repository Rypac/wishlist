import SwiftUI

public enum SFSymbol: String {
  case arrowUp = "arrow.up"
  case arrowDown = "arrow.down"
  case settings = "slider.horizontal.3"
  case share = "square.and.arrow.up"
  case trash = "trash"
  case window = "square.grid.2x2"
}

extension SFSymbol: View {
  public var body: some View {
    Image(systemName: rawValue)
  }
}
