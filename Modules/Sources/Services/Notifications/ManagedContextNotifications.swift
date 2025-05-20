import Foundation
import Toolbox

extension DarwinNotification.Name {
  private static let appIsExtension = Bundle.main.bundlePath.hasSuffix(".appex")

  /// The relevant DarwinNotification name to observe when the managed object context has been saved in an external process.
  static var didSaveManagedObjectContextExternally: DarwinNotification.Name {
    if appIsExtension {
      appDidSaveManagedObjectContext
    } else {
      extensionDidSaveManagedObjectContext
    }
  }

  /// The notification to post when a managed object context has been saved and stored to the persistent store.
  static var didSaveManagedObjectContextLocally: DarwinNotification.Name {
    if appIsExtension {
      extensionDidSaveManagedObjectContext
    } else {
      appDidSaveManagedObjectContext
    }
  }

  private static let extensionDidSaveManagedObjectContext: DarwinNotification.Name =
    "org.rypac.Watchlist.extension-did-save"

  private static let appDidSaveManagedObjectContext: DarwinNotification.Name = "org.rypac.Watchlist.app-did-save"
}
