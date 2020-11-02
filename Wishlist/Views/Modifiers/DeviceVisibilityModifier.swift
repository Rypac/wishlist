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

public extension View {
  func visible(on devices: UIUserInterfaceIdiom...) -> some View {
    modifier(DeviceVisibilityModifier(devices: Set(devices)))
  }

  func visible(on devices: Set<UIUserInterfaceIdiom>) -> some View {
    modifier(DeviceVisibilityModifier(devices: devices))
  }
}
