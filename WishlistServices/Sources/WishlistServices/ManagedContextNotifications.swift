import Foundation
import WishlistShared

extension DarwinNotification.Name {
  private static let appIsExtension = Bundle.main.bundlePath.hasSuffix(".appex")

  /// The relevant DarwinNotification name to observe when the managed object context has been saved in an external process.
  static var didSaveManagedObjectContextExternally: DarwinNotification.Name {
    if appIsExtension {
      return appDidSaveManagedObjectContext
    } else {
      return extensionDidSaveManagedObjectContext
    }
  }

  /// The notification to post when a managed object context has been saved and stored to the persistent store.
  static var didSaveManagedObjectContextLocally: DarwinNotification.Name {
    if appIsExtension {
      return extensionDidSaveManagedObjectContext
    } else {
      return appDidSaveManagedObjectContext
    }
  }

  /// Notification to be posted when the shared Core Data database has been saved to disk from an extension. Posting this notification between processes can help us fetching new changes when needed.
  private static let extensionDidSaveManagedObjectContext: DarwinNotification.Name = "org.rypac.wishlist.extension-did-save"

  /// Notification to be posted when the shared Core Data database has been saved to disk from the app. Posting this notification between processes can help us fetching new changes when needed.
  private static let appDidSaveManagedObjectContext: DarwinNotification.Name = "org.rypac.wishlist.app-did-save"
}
