import SwiftUI

struct DeviceVisibilityModifier: ViewModifier {
  struct Device: OptionSet {
    let rawValue: Int

    static let iPhone = Device(rawValue: 1 << 0)
    static let iPad = Device(rawValue: 1 << 1)
    static let tv = Device(rawValue: 1 << 2)
    static let carPlay = Device(rawValue: 1 << 3)

    static let any: Device = [.iPhone, .iPad, .tv, .carPlay]
  }

  let device: Device

  init(device: Device) {
    self.device = device
  }

  func body(content: Content) -> some View {
    if device.contains(UIDevice.current.userInterfaceIdiom.device) {
      return ViewBuilder.buildEither(first: content) as _ConditionalContent<Content, EmptyView>
    } else {
      return ViewBuilder.buildEither(second: EmptyView()) as _ConditionalContent<Content, EmptyView>
    }
  }
}

extension View {
  func visible(on device: DeviceVisibilityModifier.Device) -> some View {
    modifier(DeviceVisibilityModifier(device: device))
  }
}

private extension UIUserInterfaceIdiom {
  var device: DeviceVisibilityModifier.Device {
    switch self {
    case .phone: return .iPhone
    case .pad: return .iPad
    case .tv: return .tv
    case .carPlay: return .carPlay
    case .unspecified: return .any
    default: return .any
    }
  }
}
