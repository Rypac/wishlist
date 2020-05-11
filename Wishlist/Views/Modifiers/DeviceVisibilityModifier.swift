import SwiftUI

public struct DeviceVisibilityModifier: ViewModifier {
  private let devices: Set<UIUserInterfaceIdiom>

  public init(devices: Set<UIUserInterfaceIdiom>) {
    self.devices = devices
  }

  public func body(content: Content) -> some View {
    if devices.contains(UIDevice.current.userInterfaceIdiom) {
      return ViewBuilder.buildEither(first: content) as _ConditionalContent<Content, EmptyView>
    } else {
      return ViewBuilder.buildEither(second: EmptyView()) as _ConditionalContent<Content, EmptyView>
    }
  }
}

public extension View {
  func visible(on devices: UIUserInterfaceIdiom...) -> some View {
    modifier(DeviceVisibilityModifier(devices: Set(devices)))
  }

  func visible(on devices: Set<UIUserInterfaceIdiom>) -> some View {
    modifier(DeviceVisibilityModifier(devices: devices))
  }
}
