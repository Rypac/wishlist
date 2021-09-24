import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
  let activityItems: [Any]
  let applicationActivities: [UIActivity]?

  @Environment(\.dismiss) var dismiss

  func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityView>) -> UIActivityViewController {
    let viewController = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    viewController.completionWithItemsHandler = { _, _, _, _ in
      dismiss()
    }
    return viewController
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityView>) {}
}
