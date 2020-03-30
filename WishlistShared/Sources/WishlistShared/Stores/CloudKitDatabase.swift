import Foundation
import CloudKit

public final class CloudKitDatabase {
  private let container: CKContainer

  convenience init() {
    self.init(container: CKContainer(identifier: "iCloud.org.rypac.Wishlist"))
  }

  init(container: CKContainer) {
    self.container = container
  }
}
