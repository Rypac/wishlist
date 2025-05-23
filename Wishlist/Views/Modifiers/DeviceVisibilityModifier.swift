import SwiftUI
import UIKit

public struct DeviceVisibilityModifier: ViewModifier {
  private let devices: Set<UIUserInterfaceIdiom>

  public init(devices: Set<UIUserInterfaceIdiom>) {
    self.devices = devices
  }

  @ViewBuilder public func body(content: Content) -> some View {
    if devices.contains(UIDevice.current.userInterfaceIdiom) {
      content
    }
  }
}

extension View {
  public func visible(on devices: UIUserInterfaceIdiom...) -> some View {
    modifier(DeviceVisibilityModifier(devices: Set(devices)))
  }

  public func visible(on devices: Set<UIUserInterfaceIdiom>) -> some View {
    modifier(DeviceVisibilityModifier(devices: devices))
  }
}
