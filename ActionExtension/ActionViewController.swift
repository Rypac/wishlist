import UIKit
import Combine
import MobileCoreServices
import WishlistShared
import WishlistServices

class ActionViewController: UIViewController {

  private let wishlist = Wishlist(database: try! FileDatabase(), appLookupService: AppStoreService())

  private var cancellables = Set<AnyCancellable>()

  @IBOutlet private var statusLabel: UILabel!

  deinit {
    cancellables.forEach { cancellable in
      cancellable.cancel()
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    for item in self.extensionContext!.inputItems as! [NSExtensionItem] {
      for provider in item.attachments! {
        if provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
          weak var label = self.statusLabel
          provider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { [wishlist] data, error in
            OperationQueue.main.addOperation {
              guard let nsURL = data as? NSURL else {
                return
              }

              let url = nsURL as URL

              let matches = url.absoluteString.matchingStrings(regex: "https?://(?:itunes|apps).apple.com/(\\w+)/.*/id(\\d+)")
              guard matches.count == 1, matches[0].count == 3, let id = Int(matches[0][2]) else {
                label?.text = "Invalid App Store URL"
                return
              }

              label?.text = "Adding \(url.absoluteString)…"

              wishlist.apps
                .receive(on: DispatchQueue.main)
                .sink { [weak self] apps in
                  if apps.contains(where: { $0.id == id }) {
                    self?.done()
                  }
                }
                .store(in: &self.cancellables)

              wishlist.addApp(id: id)
            }
          }
        }
      }
    }
  }

  @IBAction func done() {
    self.extensionContext!.completeRequest(returningItems: self.extensionContext!.inputItems, completionHandler: nil)
  }
}

private extension String {
  func matchingStrings(regex: String) -> [[String]] {
    guard let regex = try? NSRegularExpression(pattern: regex, options: []) else {
      return []
    }
    let nsString = self as NSString
    let results  = regex.matches(in: self, options: [], range: NSMakeRange(0, nsString.length))
    return results.map { result in
      (0..<result.numberOfRanges).map {
        result.range(at: $0).location != NSNotFound
          ? nsString.substring(with: result.range(at: $0))
          : ""
      }
    }
  }
}
