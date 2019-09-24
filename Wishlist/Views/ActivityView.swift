import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
  @Binding var showing: Bool

  let activityItems: [Any]
  let applicationActivities: [UIActivity]?

  func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityView>) -> UIActivityViewController {
    let viewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    viewController.completionWithItemsHandler = { _, _, _, _ in
      self.showing = false
    }
    return viewController
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityView>) {}
}
