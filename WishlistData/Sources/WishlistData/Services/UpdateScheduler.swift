import Foundation

public protocol UpdateScheduler: AnyObject {
  var updateFrequency: TimeInterval { get }
  var lastUpdateDate: Date? { get set }
}
