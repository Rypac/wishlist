import Foundation
import UserDefaults
import WishlistData

public final class WishlistUpdateScheduler: UpdateScheduler {
  public let updateFrequency: TimeInterval = 15 * 60

  @UserDefault(key: "lastUpdateCheck", defaultValue: nil)
  public var lastUpdateDate: Date?

  public init() {}
}
